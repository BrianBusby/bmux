package main

import (
	"context"
	"errors"
	"fmt"
	"os"
	"strings"
	"time"

	"github.com/manaflow-ai/bmux/mux/bindings/go"
)

func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func run() error {
	socket := os.Getenv("BMUX_MUX_SOCKET")
	if socket == "" {
		return fmt.Errorf("BMUX_MUX_SOCKET is required")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()
	client, err := bmux.NewClient(bmux.Options{
		SocketPath:            socket,
		Timeout:               5 * time.Second,
		AllowProtocolV6Attach: true,
	})
	if err != nil {
		return err
	}
	defer client.Close()

	marker := fmt.Sprintf("BMUX_GO_E2E_%d_%d", os.Getpid(), time.Now().UnixNano())
	later := marker + "_ATTACH"
	info, err := client.Identify(ctx)
	if err != nil {
		return err
	}
	if info.App != "bmux-mux" || info.Protocol < 5 || info.Protocol > 6 {
		return fmt.Errorf("unexpected identify result: %+v", info)
	}
	cols, rows := uint16(80), uint16(24)
	created, err := client.NewWorkspace(ctx, bmux.NewWorkspaceOptions{Name: &marker, Cols: &cols, Rows: &rows})
	if err != nil {
		return err
	}
	text := fmt.Sprintf("printf '%s\\n'\r", marker)
	if err := client.Send(ctx, created.Surface, bmux.SendOptions{Text: &text}); err != nil {
		return err
	}
	if err := waitForMarker(ctx, client, created.Surface, marker); err != nil {
		return err
	}
	screen, err := client.ReadScreen(ctx, created.Surface)
	if err != nil {
		return err
	}
	if !strings.Contains(screen.Text, marker) {
		return fmt.Errorf("marker missing from read-screen")
	}
	tree, err := client.ListWorkspaces(ctx)
	if err != nil {
		return err
	}
	workspace, ok := findWorkspaceForSurface(tree, created.Surface)
	if !ok {
		return fmt.Errorf("workspace not found")
	}
	if err := client.RenameSurface(ctx, created.Surface, marker+"-renamed"); err != nil {
		return err
	}
	events, err := client.Subscribe(ctx)
	if err != nil {
		return err
	}
	defer events.Close()
	if err := client.ResizeSurface(ctx, created.Surface, 100, 31); err != nil {
		return err
	}
	resized, err := nextResized(events, created.Surface, time.Second)
	if err != nil {
		return err
	}
	if resized.Cols != 100 || resized.Rows != 31 {
		return fmt.Errorf("bad resize event: %+v", resized)
	}
	if err := client.ResizeSurface(ctx, created.Surface, 100, 31); err != nil {
		return err
	}
	if _, err := nextResized(events, created.Surface, 500*time.Millisecond); !errors.Is(err, bmux.ErrTimeout) {
		return fmt.Errorf("same-size resize emitted event or failed oddly: %v", err)
	}

	attach, err := client.AttachSurface(ctx, created.Surface)
	if err != nil {
		return err
	}
	defer attach.Close()
	first, err := attach.Recv(ctx)
	if err != nil {
		return err
	}
	if first.EventName() != "vt-state" {
		return fmt.Errorf("first attach event was %s", first.EventName())
	}
	outputText := fmt.Sprintf("printf '%s\\n'\r", later)
	if err := client.Send(ctx, created.Surface, bmux.SendOptions{Text: &outputText}); err != nil {
		return err
	}
	if err := nextAttachOutput(attach, 3*time.Second); err != nil {
		return err
	}
	if err := client.CloseWorkspace(ctx, workspace); err != nil {
		return err
	}
	afterClose, err := client.ListWorkspaces(ctx)
	if err != nil {
		return err
	}
	if _, ok := findWorkspaceForSurface(afterClose, created.Surface); ok {
		return fmt.Errorf("closed workspace still present")
	}
	_, err = client.ReadScreen(ctx, created.Surface)
	var commandErr *bmux.CommandError
	if !errors.As(err, &commandErr) || commandErr.Message == "" {
		return fmt.Errorf("closed surface error was not command error preserving message: %v", err)
	}
	return nil
}

func waitForMarker(ctx context.Context, client *bmux.Client, surface uint64, marker string) error {
	deadline := time.Now().Add(5 * time.Second)
	last := ""
	for time.Now().Before(deadline) {
		screen, err := client.ReadScreen(ctx, surface)
		if err != nil {
			return err
		}
		last = screen.Text
		if strings.Contains(last, marker) {
			return nil
		}
		time.Sleep(50 * time.Millisecond)
	}
	return fmt.Errorf("marker not found; last screen: %q", last)
}

func nextResized(events *bmux.Stream, surface uint64, timeout time.Duration) (bmux.SurfaceResizedEvent, error) {
	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()
	for {
		event, err := events.Recv(ctx)
		if err != nil {
			return bmux.SurfaceResizedEvent{}, err
		}
		if resized, ok := event.(bmux.SurfaceResizedEvent); ok && resized.Surface == surface {
			return resized, nil
		}
	}
}

func nextAttachOutput(events *bmux.Stream, timeout time.Duration) error {
	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()
	for {
		event, err := events.Recv(ctx)
		if err != nil {
			return err
		}
		if event.EventName() == "output" || event.EventName() == "resized" {
			return nil
		}
	}
}

func findWorkspaceForSurface(tree bmux.Tree, surface uint64) (uint64, bool) {
	for _, workspace := range tree.Workspaces {
		for _, screen := range workspace.Screens {
			for _, pane := range screen.Panes {
				for _, tab := range pane.Tabs {
					if tab.Surface == surface {
						return workspace.ID, true
					}
				}
			}
		}
	}
	return 0, false
}
