package main

import (
	"fmt"
	"os"
)

var version = "dev"

func main() {
	if len(os.Args) < 2 {
		usage()
		os.Exit(1)
	}
	switch os.Args[1] {
	case "status":
		cmdStatus()
	case "today":
		cmdToday()
	case "projects":
		cmdProjects()
	case "tasks":
		cmdTasks()
	case "stop":
		cmdStop()
	case "resume":
		cmdResume()
	case "start":
		cmdStart()
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
  --version           Print version
  --help              Print this help`)
}

func cmdStatus()   { fmt.Println("stopped 0.0") }
func cmdToday()    {}
func cmdProjects() {}
func cmdTasks()    {}
func cmdStop()     { fmt.Fprintln(os.Stderr, "not implemented") }
func cmdResume()   { fmt.Fprintln(os.Stderr, "not implemented") }
func cmdStart()    { fmt.Fprintln(os.Stderr, "not implemented") }
