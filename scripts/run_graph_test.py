#!/usr/bin/env python3
"""
MTA San Andreas Graph Testing Automation Script

This script automates the testing workflow for graph-based story simulations:
1. Updates INPUT_GRAPHS in ServerGlobals.lua with the specified graph path
2. Starts the MTA server
3. Starts the MTA client
4. Monitors the output folder for completion or errors
5. Supports retry logic for failed executions

Usage:
    python run_graph_test.py <graph_path> [--retries N] [--output-dir DIR] [--timeout SECONDS]

Example:
    python run_graph_test.py "random/v1_1actor/g0" --retries 3
"""

import argparse
import os
import re
import subprocess
import sys
import time
from pathlib import Path
from typing import Optional, Tuple


class GraphTestRunner:
    """Manages automated testing of MTA graph simulations."""

    def __init__(
        self,
        graph_path: str,
        server_globals_path: Path,
        server_exe_path: Path,
        client_exe_path: Path,
        base_output_dir: Path,
        timeout: int = 3600,
        retries: int = 0
    ):
        """
        Initialize the test runner.

        Args:
            graph_path: Path to the graph file (relative to graphs directory)
            server_globals_path: Path to ServerGlobals.lua
            server_exe_path: Path to MTA server executable
            client_exe_path: Path to MTA client executable/shortcut
            base_output_dir: Base output directory (graph-specific dir will be created)
            timeout: Maximum time to wait for test completion (seconds)
            retries: Number of retry attempts on failure
        """
        self.graph_path = graph_path
        self.server_globals_path = server_globals_path
        self.server_exe_path = server_exe_path
        self.client_exe_path = client_exe_path
        # Create graph-specific output directory: {graph_path}_out/
        self.output_dir = base_output_dir / f"{graph_path}_out"
        self.timeout = timeout
        self.retries = retries
        self.server_process: Optional[subprocess.Popen] = None
        self.client_process: Optional[subprocess.Popen] = None

    def update_server_globals(self) -> bool:
        """
        Update INPUT_GRAPHS in ServerGlobals.lua with the specified graph path.

        Returns:
            True if successful, False otherwise
        """
        try:
            print(f"[INFO] Updating ServerGlobals.lua with graph: {self.graph_path}")

            # Read the file
            with open(self.server_globals_path, 'r', encoding='utf-8') as f:
                content = f.read()

            # Pattern to match INPUT_GRAPHS table
            pattern = r'(INPUT_GRAPHS\s*=\s*\{)(.*?)(\})'

            def replace_input_graphs(match):
                # Create new table content with only the specified graph
                new_content = f"\n    '{self.graph_path}',\n"
                return match.group(1) + new_content + match.group(3)

            # Replace the INPUT_GRAPHS table
            new_content = re.sub(pattern, replace_input_graphs, content, flags=re.DOTALL)

            # Write back
            with open(self.server_globals_path, 'w', encoding='utf-8') as f:
                f.write(new_content)

            print(f"[SUCCESS] ServerGlobals.lua updated successfully")
            return True

        except Exception as e:
            print(f"[ERROR] Failed to update ServerGlobals.lua: {e}")
            return False

    def start_server(self) -> bool:
        """
        Start the MTA server process.

        Returns:
            True if server started successfully, False otherwise
        """
        try:
            print(f"[INFO] Starting MTA server: {self.server_exe_path}")

            # Start server process
            self.server_process = subprocess.Popen(
                [str(self.server_exe_path)],
                cwd=self.server_exe_path.parent,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                creationflags=subprocess.CREATE_NEW_CONSOLE if sys.platform == 'win32' else 0
            )

            # Give server time to initialize
            time.sleep(5)

            # Check if process is still running
            if self.server_process.poll() is not None:
                print(f"[ERROR] Server process terminated unexpectedly")
                return False

            print(f"[SUCCESS] Server started (PID: {self.server_process.pid})")
            return True

        except Exception as e:
            print(f"[ERROR] Failed to start server: {e}")
            return False

    def start_client(self) -> bool:
        """
        Start the MTA client process.

        Returns:
            True if client started successfully, False otherwise
        """
        try:
            print(f"[INFO] Starting MTA client: {self.client_exe_path}")

            # Handle .lnk shortcuts on Windows
            if sys.platform == 'win32' and self.client_exe_path.suffix == '.lnk':
                # Use explorer to launch the shortcut
                self.client_process = subprocess.Popen(
                    ['cmd', '/c', 'start', '', str(self.client_exe_path)],
                    cwd=self.client_exe_path.parent,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    shell=True
                )
            else:
                self.client_process = subprocess.Popen(
                    [str(self.client_exe_path)],
                    cwd=self.client_exe_path.parent,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    creationflags=subprocess.CREATE_NEW_CONSOLE if sys.platform == 'win32' else 0
                )

            # Give client time to initialize
            time.sleep(5)

            print(f"[SUCCESS] Client started")
            return True

        except Exception as e:
            print(f"[ERROR] Failed to start client: {e}")
            return False

    def monitor_output(self) -> Tuple[bool, str]:
        """
        Monitor the output directory for completion or error files.

        Returns:
            Tuple of (success, message)
        """
        print(f"[INFO] Monitoring output directory: {self.output_dir}")
        print(f"[INFO] Timeout: {self.timeout} seconds")

        start_time = time.time()
        last_log_time = 0

        while time.time() - start_time < self.timeout:
            # Check if output directory exists (created by the simulation)
            if not self.output_dir.exists():
                # Wait for output directory to be created
                time.sleep(2)
                continue

            # Check for error files
            error_files = list(self.output_dir.glob("**/ERROR*"))
            if error_files:
                error_msg = f"ERROR file detected: {error_files[0]}"
                print(f"[FAILURE] {error_msg}")
                return False, error_msg

            # Check for MAX_STORY_TIME_EXCEEDED
            max_time_files = list(self.output_dir.glob("**/MAX_STORY_TIME_EXCEEDED*"))
            if max_time_files:
                error_msg = f"MAX_STORY_TIME_EXCEEDED detected: {max_time_files[0]}"
                print(f"[FAILURE] {error_msg}")
                return False, error_msg

            # Check for successful completion markers
            # You may need to adjust this based on how your system indicates success
            success_files = list(self.output_dir.glob("**/SUCCESS*"))
            if success_files:
                success_msg = f"SUCCESS file detected: {success_files[0]}"
                print(f"[SUCCESS] {success_msg}")
                return True, success_msg

            # Check for video output files as potential success indicator
            video_files = list(self.output_dir.glob("**/*.mp4"))
            if video_files:
                # Check if video was recently created (within last 30 seconds)
                for video_file in video_files:
                    if time.time() - video_file.stat().st_mtime < 30:
                        success_msg = f"Video output detected: {video_file}"
                        print(f"[SUCCESS] {success_msg}")
                        return True, success_msg

            # Wait before checking again
            time.sleep(2)

            # Print progress every 30 seconds
            elapsed = int(time.time() - start_time)
            if elapsed % 30 == 0 and elapsed > last_log_time:
                print(f"[INFO] Still monitoring... ({elapsed}/{self.timeout}s elapsed)")
                last_log_time = elapsed

        # Timeout reached
        timeout_msg = f"Timeout reached ({self.timeout}s) without detecting completion"
        print(f"[FAILURE] {timeout_msg}")
        return False, timeout_msg

    def cleanup(self):
        """Terminate server and client processes."""
        print(f"[INFO] Cleaning up processes...")

        if self.client_process:
            try:
                self.client_process.terminate()
                self.client_process.wait(timeout=10)
                print(f"[INFO] Client process terminated")
            except Exception as e:
                print(f"[WARNING] Error terminating client: {e}")
                try:
                    self.client_process.kill()
                except:
                    pass

        if self.server_process:
            try:
                self.server_process.terminate()
                self.server_process.wait(timeout=10)
                print(f"[INFO] Server process terminated")
            except Exception as e:
                print(f"[WARNING] Error terminating server: {e}")
                try:
                    self.server_process.kill()
                except:
                    pass

    def run_test(self, attempt: int = 1) -> bool:
        """
        Run a single test attempt.

        Args:
            attempt: Current attempt number (for logging)

        Returns:
            True if test passed, False otherwise
        """
        print(f"\n{'='*80}")
        print(f"ATTEMPT {attempt}/{self.retries + 1}: Testing graph '{self.graph_path}'")
        print(f"{'='*80}\n")

        try:
            # Step 1: Update ServerGlobals.lua
            if not self.update_server_globals():
                return False

            # Step 2: Start server
            if not self.start_server():
                return False

            # Step 3: Start client
            if not self.start_client():
                return False

            # Step 4: Monitor for completion
            success, message = self.monitor_output()

            return success

        finally:
            # Always cleanup
            self.cleanup()

            # Wait a bit before potential retry
            if attempt <= self.retries:
                print(f"\n[INFO] Waiting 10 seconds before next attempt...")
                time.sleep(10)

    def run_with_retries(self) -> bool:
        """
        Run the test with retry logic.

        Returns:
            True if any attempt succeeded, False if all failed
        """
        for attempt in range(1, self.retries + 2):
            if self.run_test(attempt):
                print(f"\n{'='*80}")
                print(f"TEST PASSED on attempt {attempt}/{self.retries + 1}")
                print(f"{'='*80}\n")
                return True

        print(f"\n{'='*80}")
        print(f"TEST FAILED after {self.retries + 1} attempts")
        print(f"{'='*80}\n")
        return False


def main():
    """Main entry point for the script."""
    parser = argparse.ArgumentParser(
        description="Automate MTA graph simulation testing with retry logic",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python run_graph_test.py "random/v1_1actor/g0"
  python run_graph_test.py "complex_graphs/c10_sync.json" --retries 3
  python run_graph_test.py "random/v1_1actor/g0" --timeout 7200 --retries 5
        """
    )

    parser.add_argument(
        'graph_path',
        help='Path to the graph file (e.g., "random/v1_1actor/g0")'
    )

    parser.add_argument(
        '--retries',
        type=int,
        default=0,
        help='Number of retry attempts on failure (default: 0)'
    )

    parser.add_argument(
        '--timeout',
        type=int,
        default=3600,
        help='Timeout in seconds for each test attempt (default: 3600)'
    )

    parser.add_argument(
        '--base-output-dir',
        type=str,
        default='.',
        help='Base output directory (graph-specific folder will be created as {graph_path}_out, default: current directory)'
    )

    parser.add_argument(
        '--server-globals',
        type=str,
        default=r'src\ServerGlobals.lua',
        help='Path to ServerGlobals.lua (default: src\\ServerGlobals.lua)'
    )

    parser.add_argument(
        '--server-exe',
        type=str,
        default=r'..\..\..\MTA Server.exe',
        help='Path to MTA server executable (default: ..\\..\\..\\MTA Server.exe)'
    )

    parser.add_argument(
        '--client-exe',
        type=str,
        default=r'..\..\..\..\..\..\Multi Theft Auto.exe - Shortcut.lnk',
        help='Path to MTA client executable or shortcut (default: ..\\..\\..\\..\\..\\..\\Multi Theft Auto.exe - Shortcut.lnk)'
    )

    args = parser.parse_args()

    # Resolve paths
    script_dir = Path(__file__).parent
    server_globals_path = (script_dir / args.server_globals).resolve()
    server_exe_path = (script_dir / args.server_exe).resolve()
    client_exe_path = (script_dir / args.client_exe).resolve()
    base_output_dir = (script_dir / args.base_output_dir).resolve()

    # Validate paths
    if not server_globals_path.exists():
        print(f"[ERROR] ServerGlobals.lua not found: {server_globals_path}")
        sys.exit(1)

    if not server_exe_path.exists():
        print(f"[ERROR] Server executable not found: {server_exe_path}")
        sys.exit(1)

    if not client_exe_path.exists():
        print(f"[ERROR] Client executable/shortcut not found: {client_exe_path}")
        sys.exit(1)

    # Base output directory should exist (but graph-specific dir will be created by simulation)
    if not base_output_dir.exists():
        print(f"[WARNING] Base output directory does not exist, creating: {base_output_dir}")
        base_output_dir.mkdir(parents=True, exist_ok=True)

    # Create and run the test runner
    runner = GraphTestRunner(
        graph_path=args.graph_path,
        server_globals_path=server_globals_path,
        server_exe_path=server_exe_path,
        client_exe_path=client_exe_path,
        base_output_dir=base_output_dir,
        timeout=args.timeout,
        retries=args.retries
    )

    success = runner.run_with_retries()
    sys.exit(0 if success else 1)


if __name__ == '__main__':
    main()
