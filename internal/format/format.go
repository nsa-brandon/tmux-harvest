package format

import (
	"fmt"
	"math"
	"sort"
	"strings"

	"github.com/brandondedolph/tmux-harvest/internal/api"
)

// FmtHours formats hours to up to 2 decimal places, trimming trailing zeros.
// 1.25 → "1.25", 1.20 → "1.2", 1.00 → "1"
func FmtHours(h float64) string {
	s := fmt.Sprintf("%.2f", h)
	s = strings.TrimRight(s, "0")
	s = strings.TrimRight(s, ".")
	return s
}

func Status(running *api.TimeEntry, todayEntries []api.TimeEntry) string {
	total := 0.0
	for _, e := range todayEntries {
		total += e.Hours
	}
	if running != nil && running.IsRunning {
		h := int(running.Hours)
		m := int(math.Round((running.Hours - float64(h)) * 60))
		return fmt.Sprintf("running %d:%02d", h, m)
	}
	return fmt.Sprintf("stopped %s", FmtHours(total))
}

// TodayTSV returns today's entries as TSV lines.
// Format: entry_id\thours\tproject_code\ttask\tnotes
// Last line: 0\ttotal_hours\tTOTAL\t\t
func TodayTSV(entries []api.TimeEntry) string {
	var lines []string
	total := 0.0
	for _, e := range entries {
		total += e.Hours
		notes := strings.ReplaceAll(e.Notes, "\t", " ")
		notes = strings.ReplaceAll(notes, "\n", " ")
		lines = append(lines, fmt.Sprintf("%d\t%s\t%s\t%s\t%s",
			e.ID, FmtHours(e.Hours), e.Project.Code, e.Task.Name, notes))
	}
	lines = append(lines, fmt.Sprintf("0\t%s\tTOTAL\t\t", FmtHours(total)))
	return strings.Join(lines, "\n")
}

func ProjectsTSV(assignments []api.ProjectAssignment) string {
	sorted := make([]api.ProjectAssignment, len(assignments))
	copy(sorted, assignments)
	sort.Slice(sorted, func(i, j int) bool {
		return sorted[i].Project.Code < sorted[j].Project.Code
	})
	var lines []string
	for _, a := range sorted {
		lines = append(lines, fmt.Sprintf("%d\t%s\t%s",
			a.Project.ID, a.Project.Code, a.Project.Name))
	}
	return strings.Join(lines, "\n")
}

func TasksTSV(assignment *api.ProjectAssignment) string {
	var lines []string
	for _, ta := range assignment.TaskAssignments {
		lines = append(lines, fmt.Sprintf("%d\t%s",
			ta.Task.ID, ta.Task.Name))
	}
	return strings.Join(lines, "\n")
}
