package main

import (
	"fmt"
	"os"
	"strconv"
	"time"

	"github.com/brandondedolph/tmux-harvest/internal/api"
	"github.com/brandondedolph/tmux-harvest/internal/cache"
	"github.com/brandondedolph/tmux-harvest/internal/config"
	"github.com/brandondedolph/tmux-harvest/internal/format"
)

var version = "dev"

const (
	statusCacheTTL  = 30 * time.Second
	projectCacheTTL = 5 * time.Minute
)

func main() {
	if len(os.Args) < 2 {
		usage()
		os.Exit(1)
	}
	switch os.Args[1] {
	case "status":
		run(cmdStatus)
	case "today":
		run(cmdToday)
	case "projects":
		run(cmdProjects)
	case "tasks":
		run(cmdTasks)
	case "stop":
		run(cmdStop)
	case "resume":
		run(cmdResume)
	case "start":
		run(cmdStart)
	case "log":
		run(cmdLog)
	case "edit":
		run(cmdEdit)
	case "--version":
		fmt.Println("harvest-tmux", version)
	case "--help":
		usage()
	default:
		fmt.Fprintf(os.Stderr, "unknown command: %s\n", os.Args[1])
		usage()
		os.Exit(1)
	}
}

func usage() {
	fmt.Fprintln(os.Stderr, `Usage: harvest-tmux <command>

Commands:
  status              Current timer status (machine-readable)
  today               Today's time entries (TSV)
  projects            Active projects (TSV)
  tasks <project_id>  Tasks for a project (TSV)
  stop                Stop running timer
  resume              Resume last entry
  start <pid> <tid>   Start new entry (-n "notes")
  log <pid> <tid> <h> Log time without timer (-n "notes")
  edit <entry_id>     Update entry (--project, --task, --hours, --notes)
  --version           Print version
  --help              Print this help`)
}

type clientFunc func(c *api.Client) error

func run(fn clientFunc) {
	cfg, err := config.Load()
	if err != nil {
		fmt.Fprintf(os.Stderr, "config error: %v\n", err)
		os.Exit(1)
	}
	client := api.NewClient(cfg)
	if err := fn(client); err != nil {
		fmt.Fprintf(os.Stderr, "error: %v\n", err)
		os.Exit(1)
	}
}

type statusCache struct {
	Running *api.TimeEntry  `json:"running"`
	Entries []api.TimeEntry `json:"entries"`
}

func fetchStatus(c *api.Client) (*statusCache, error) {
	var sc statusCache
	if cache.Get("status", &sc) {
		return &sc, nil
	}
	running, err := c.RunningTimer()
	if err != nil {
		return nil, err
	}
	entries, err := c.TodayEntries()
	if err != nil {
		return nil, err
	}
	sc = statusCache{Running: running, Entries: entries}
	cache.Set("status", &sc, statusCacheTTL)
	return &sc, nil
}

func cmdStatus(c *api.Client) error {
	sc, err := fetchStatus(c)
	if err != nil {
		fmt.Println("error --")
		return nil
	}
	fmt.Println(format.Status(sc.Running, sc.Entries))
	return nil
}

func cmdToday(c *api.Client) error {
	sc, err := fetchStatus(c)
	if err != nil {
		return err
	}
	out := format.TodayTSV(sc.Entries)
	if out != "" {
		fmt.Println(out)
	}
	return nil
}

func cmdProjects(c *api.Client) error {
	assignments, err := getAssignments(c)
	if err != nil {
		return err
	}
	fmt.Println(format.ProjectsTSV(assignments))
	return nil
}

func getAssignments(c *api.Client) ([]api.ProjectAssignment, error) {
	var assignments []api.ProjectAssignment
	if cache.Get("projects", &assignments) {
		return assignments, nil
	}
	var err error
	assignments, err = c.ProjectAssignments()
	if err != nil {
		return nil, err
	}
	cache.Set("projects", assignments, projectCacheTTL)
	return assignments, nil
}

func cmdTasks(c *api.Client) error {
	if len(os.Args) < 3 {
		return fmt.Errorf("usage: harvest-tmux tasks <project_id>")
	}
	pid, err := strconv.ParseInt(os.Args[2], 10, 64)
	if err != nil {
		return fmt.Errorf("invalid project_id: %s", os.Args[2])
	}
	assignments, err := getAssignments(c)
	if err != nil {
		return err
	}
	for _, a := range assignments {
		if a.Project.ID == pid {
			fmt.Println(format.TasksTSV(&a))
			return nil
		}
	}
	return fmt.Errorf("project %d not found in assignments", pid)
}

func cmdStop(c *api.Client) error {
	running, err := c.RunningTimer()
	if err != nil {
		return err
	}
	if running == nil {
		return fmt.Errorf("no running timer")
	}
	stopped, err := c.StopTimer(running.ID)
	if err != nil {
		return err
	}
	entries, _ := c.TodayEntries()
	cache.Set("status", &statusCache{Running: nil, Entries: entries}, statusCacheTTL)
	fmt.Printf("Stopped: %s %s (%.1fh)\n", stopped.Project.Code, stopped.Task.Name, stopped.Hours)
	return nil
}

func cmdResume(c *api.Client) error {
	entries, err := c.TodayEntries()
	if err != nil {
		return err
	}
	if len(entries) == 0 {
		return fmt.Errorf("no entries today to resume")
	}
	last := entries[0]
	restarted, err := c.RestartTimer(last.ID)
	if err != nil {
		return err
	}
	cache.Set("status", &statusCache{Running: restarted, Entries: entries}, statusCacheTTL)
	fmt.Printf("Resumed: %s %s\n", restarted.Project.Code, restarted.Task.Name)
	return nil
}

func cmdStart(c *api.Client) error {
	if len(os.Args) < 4 {
		return fmt.Errorf("usage: harvest-tmux start <project_id> <task_id> [-n \"notes\"]")
	}
	pid, err := strconv.ParseInt(os.Args[2], 10, 64)
	if err != nil {
		return fmt.Errorf("invalid project_id: %s", os.Args[2])
	}
	tid, err := strconv.ParseInt(os.Args[3], 10, 64)
	if err != nil {
		return fmt.Errorf("invalid task_id: %s", os.Args[3])
	}
	var notes string
	for i := 4; i < len(os.Args); i++ {
		if os.Args[i] == "-n" && i+1 < len(os.Args) {
			notes = os.Args[i+1]
			break
		}
	}
	entry, err := c.CreateEntry(pid, tid, notes)
	if err != nil {
		return err
	}
	entries, _ := c.TodayEntries()
	cache.Set("status", &statusCache{Running: entry, Entries: entries}, statusCacheTTL)
	fmt.Printf("Started: %s %s\n", entry.Project.Code, entry.Task.Name)
	return nil
}

func cmdLog(c *api.Client) error {
	if len(os.Args) < 5 {
		return fmt.Errorf("usage: harvest-tmux log <project_id> <task_id> <hours> [-n \"notes\"]")
	}
	pid, err := strconv.ParseInt(os.Args[2], 10, 64)
	if err != nil {
		return fmt.Errorf("invalid project_id: %s", os.Args[2])
	}
	tid, err := strconv.ParseInt(os.Args[3], 10, 64)
	if err != nil {
		return fmt.Errorf("invalid task_id: %s", os.Args[3])
	}
	hours, err := strconv.ParseFloat(os.Args[4], 64)
	if err != nil {
		return fmt.Errorf("invalid hours: %s", os.Args[4])
	}
	var notes string
	for i := 5; i < len(os.Args); i++ {
		if os.Args[i] == "-n" && i+1 < len(os.Args) {
			notes = os.Args[i+1]
			break
		}
	}
	entry, err := c.LogEntry(pid, tid, hours, notes)
	if err != nil {
		return err
	}
	entries, _ := c.TodayEntries()
	cache.Set("status", &statusCache{Running: nil, Entries: entries}, statusCacheTTL)
	fmt.Printf("Logged: %s %s (%.1fh)\n", entry.Project.Code, entry.Task.Name, entry.Hours)
	return nil
}

func cmdEdit(c *api.Client) error {
	if len(os.Args) < 3 {
		return fmt.Errorf("usage: harvest-tmux edit <entry_id> [--project <pid>] [--task <tid>] [--hours <h>] [--notes <text>]")
	}
	entryID, err := strconv.ParseInt(os.Args[2], 10, 64)
	if err != nil {
		return fmt.Errorf("invalid entry_id: %s", os.Args[2])
	}
	var fields api.UpdateFields
	for i := 3; i < len(os.Args); i++ {
		if i+1 >= len(os.Args) {
			break
		}
		switch os.Args[i] {
		case "--project":
			pid, err := strconv.ParseInt(os.Args[i+1], 10, 64)
			if err != nil {
				return fmt.Errorf("invalid project_id: %s", os.Args[i+1])
			}
			fields.ProjectID = &pid
			i++
		case "--task":
			tid, err := strconv.ParseInt(os.Args[i+1], 10, 64)
			if err != nil {
				return fmt.Errorf("invalid task_id: %s", os.Args[i+1])
			}
			fields.TaskID = &tid
			i++
		case "--hours":
			h, err := strconv.ParseFloat(os.Args[i+1], 64)
			if err != nil {
				return fmt.Errorf("invalid hours: %s", os.Args[i+1])
			}
			fields.Hours = &h
			i++
		case "--notes":
			fields.Notes = &os.Args[i+1]
			i++
		}
	}
	entry, err := c.UpdateEntry(entryID, fields)
	if err != nil {
		return err
	}
	cache.Invalidate("status")
	fmt.Printf("Updated: %s %s (%.1fh)\n", entry.Project.Code, entry.Task.Name, entry.Hours)
	return nil
}
