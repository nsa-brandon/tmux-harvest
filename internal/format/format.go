package format

import (
	"fmt"
	"math"
	"strings"

	"github.com/brandondedolph/tmux-harvest/internal/api"
)

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
	return fmt.Sprintf("stopped %.1f", total)
}

func TodayTSV(entries []api.TimeEntry) string {
	var lines []string
	total := 0.0
	for _, e := range entries {
		total += e.Hours
		notes := strings.ReplaceAll(e.Notes, "\t", " ")
		notes = strings.ReplaceAll(notes, "\n", " ")
		lines = append(lines, fmt.Sprintf("%.1f\t%s\t%s\t%s",
			e.Hours, e.Project.Code, e.Task.Name, notes))
	}
	lines = append(lines, fmt.Sprintf("%.1f\tTOTAL\t\t", total))
	return strings.Join(lines, "\n")
}

func ProjectsTSV(assignments []api.ProjectAssignment) string {
	var lines []string
	for _, a := range assignments {
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
