#!/usr/bin/env python3
"""
Build and run script for KMReader.
Provides device selection with persistence.
"""

import argparse
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Dict, List, Optional


def is_interactive() -> bool:
    """Check if running in an interactive terminal."""
    return sys.stdin.isatty() and sys.stdout.isatty()


class Color:
    GREEN = "\033[0;32m"
    YELLOW = "\033[1;33m"
    RED = "\033[0;31m"
    BLUE = "\033[0;34m"
    NC = "\033[0m"


class Device:
    def __init__(
        self, name: str, udid: str, state: str, platform: str, is_available: bool = True
    ):
        self.name = name
        self.udid = udid
        self.state = state
        self.platform = platform
        self.is_available = is_available

    def __repr__(self):
        status = f"({self.state})" if self.state else ""
        return f"{self.name} [{self.udid}] {status}"


class DeviceManager:
    DEVICES_FILE = "devices.json"

    def __init__(self):
        self.devices_file = Path(self.DEVICES_FILE)
        self.saved_devices = self._load_saved_devices()

    def _load_saved_devices(self) -> Dict[str, str]:
        """Load saved device preferences from JSON file."""
        if self.devices_file.exists():
            try:
                with open(self.devices_file, "r") as f:
                    return json.load(f)
            except (json.JSONDecodeError, IOError) as e:
                print(
                    f"{Color.YELLOW}Warning: Could not load {self.DEVICES_FILE}: {e}{Color.NC}"
                )
                return {}
        return {}

    def _save_devices(self):
        """Save device preferences to JSON file."""
        try:
            with open(self.devices_file, "w") as f:
                json.dump(self.saved_devices, f, indent=2)
        except IOError as e:
            print(
                f"{Color.YELLOW}Warning: Could not save {self.DEVICES_FILE}: {e}{Color.NC}"
            )

    def list_simulators(self, platform: str) -> List[Device]:
        """List available simulators for the given platform."""
        try:
            result = subprocess.run(
                ["xcrun", "simctl", "list", "devices", "--json"],
                capture_output=True,
                text=True,
                check=True,
            )
            data = json.loads(result.stdout)
            devices = []

            platform_filter = {
                "ios": "com.apple.CoreSimulator.SimRuntime.iOS",
                "tvos": "com.apple.CoreSimulator.SimRuntime.tvOS",
            }

            runtime_prefix = platform_filter.get(platform.lower())
            if not runtime_prefix:
                return devices

            for runtime, device_list in data["devices"].items():
                if runtime.startswith(runtime_prefix):
                    for device in device_list:
                        if device.get("isAvailable", False):
                            devices.append(
                                Device(
                                    name=device["name"],
                                    udid=device["udid"],
                                    state=device.get("state", ""),
                                    platform=platform,
                                    is_available=True,
                                )
                            )

            return devices
        except (subprocess.CalledProcessError, json.JSONDecodeError, KeyError) as e:
            print(f"{Color.RED}Error listing simulators: {e}{Color.NC}")
            return []

    def list_physical_devices(self, platform: str) -> List[Device]:
        """List available physical devices for the given platform."""
        platform_aliases = {
            "ios": {"ios"},
            "tvos": {"tvos"},
        }

        target_platforms = platform_aliases.get(platform.lower())
        if not target_platforms:
            return []

        # Prefer CoreDevice JSON output, which is stable for scripting and works
        # regardless of the user-assigned device name.
        json_output_path: Optional[str] = None
        try:
            with tempfile.NamedTemporaryFile(suffix=".json", delete=False) as tmp:
                json_output_path = tmp.name

            subprocess.run(
                [
                    "xcrun",
                    "devicectl",
                    "list",
                    "devices",
                    "--json-output",
                    json_output_path,
                ],
                capture_output=True,
                text=True,
                check=True,
            )

            with open(json_output_path, "r") as f:
                payload = json.load(f)

            devices: List[Device] = []
            for item in payload.get("result", {}).get("devices", []):
                hardware = item.get("hardwareProperties", {})
                if hardware.get("reality") != "physical":
                    continue

                hardware_platform = str(hardware.get("platform", "")).lower()
                if hardware_platform not in target_platforms:
                    continue

                udid = hardware.get("udid")
                if not udid:
                    continue

                device_props = item.get("deviceProperties", {})
                connection_props = item.get("connectionProperties", {})

                name = device_props.get("name") or hardware.get("marketingName") or "Unknown Device"
                state = connection_props.get("tunnelState") or connection_props.get("pairingState") or ""

                devices.append(
                    Device(
                        name=name,
                        udid=udid,
                        state=state,
                        platform=platform,
                        is_available=True,
                    )
                )

            return devices
        except (subprocess.CalledProcessError, json.JSONDecodeError, IOError) as e:
            print(
                f"{Color.YELLOW}Warning: Could not list physical devices via devicectl: {e}{Color.NC}"
            )
        finally:
            if json_output_path and os.path.exists(json_output_path):
                try:
                    os.remove(json_output_path)
                except OSError:
                    pass

        # Fallback for older toolchains where devicectl is unavailable.
        try:
            result = subprocess.run(
                ["xcrun", "xctrace", "list", "devices"],
                capture_output=True,
                text=True,
                check=True,
            )

            devices = []
            platform_names = {
                "ios": "iPhone",
                "tvos": "Apple TV",
            }

            platform_name = platform_names.get(platform.lower())
            if not platform_name:
                return devices

            for line in result.stdout.split("\n"):
                line = line.strip()
                if "Simulator" in line:
                    continue
                if platform_name in line and "(" in line and ")" in line:
                    parts = line.rsplit("(", 1)
                    if len(parts) == 2:
                        name_part = parts[0].strip()
                        udid = parts[1].rstrip(")").strip()

                        if "(" in name_part:
                            name = name_part.rsplit("(", 1)[0].strip()
                        else:
                            name = name_part

                        devices.append(
                            Device(
                                name=name,
                                udid=udid,
                                state="",
                                platform=platform,
                                is_available=True,
                            )
                        )

            return devices
        except subprocess.CalledProcessError as e:
            print(
                f"{Color.YELLOW}Warning: Could not list physical devices: {e}{Color.NC}"
            )
            return []

    def get_device_key(self, platform: str, is_simulator: bool) -> str:
        """Generate key for storing device preference."""
        device_type = "simulator" if is_simulator else "device"
        return f"{platform.lower()}_{device_type}"

    def get_saved_device(self, platform: str, is_simulator: bool) -> Optional[str]:
        """Get saved device UDID for platform and type."""
        key = self.get_device_key(platform, is_simulator)
        return self.saved_devices.get(key)

    def save_device(self, platform: str, is_simulator: bool, udid: str):
        """Save device preference."""
        key = self.get_device_key(platform, is_simulator)
        self.saved_devices[key] = udid
        self._save_devices()

    def select_device(
        self,
        platform: str,
        is_simulator: bool,
        device_arg: Optional[str] = None,
        force_select: bool = False,
    ) -> Optional[str]:
        """
        Select a device interactively or from saved preferences.
        In non-interactive mode, automatically selects the first available device.

        Args:
            platform: Target platform (ios, tvos)
            is_simulator: Whether to select simulator or physical device
            device_arg: Optional specific device name or UDID
            force_select: If True, always show selection prompt even if saved device exists

        Returns device UDID or None if selection failed.
        """
        # List available devices
        if is_simulator:
            devices = self.list_simulators(platform)
            device_type_name = "simulator"
        else:
            devices = self.list_physical_devices(platform)
            device_type_name = "device"

        if not devices:
            print(f"{Color.RED}No {platform} {device_type_name}s found{Color.NC}")
            return None

        # If device specified by argument, try to find it
        if device_arg:
            for device in devices:
                if device_arg in (device.name, device.udid):
                    return device.udid
            print(f"{Color.YELLOW}Device '{device_arg}' not found{Color.NC}")

        # Check for saved device (skip if force_select is True)
        if not force_select:
            saved_udid = self.get_saved_device(platform, is_simulator)
            if saved_udid:
                for device in devices:
                    if device.udid == saved_udid:
                        print(
                            f"{Color.GREEN}Using saved {device_type_name}: {device.name}{Color.NC}"
                        )
                        return device.udid
                print(
                    f"{Color.YELLOW}Saved {device_type_name} no longer available{Color.NC}"
                )

        # Check if running in interactive mode
        interactive = is_interactive()
        mode_indicator = f"{Color.BLUE}[{'Interactive' if interactive else 'Non-interactive'} mode]{Color.NC}"

        # Non-interactive mode: automatically select first device
        if not interactive:
            selected = devices[0]
            print(f"{mode_indicator}")
            print(
                f"{Color.GREEN}Auto-selecting {device_type_name}: {selected.name}{Color.NC}"
            )
            # Save as default in non-interactive mode
            self.save_device(platform, is_simulator, selected.udid)
            return selected.udid

        # Interactive selection
        print(f"{mode_indicator}")
        print(
            f"\n{Color.BLUE}Available {platform.upper()} {device_type_name}s:{Color.NC}"
        )
        for i, device in enumerate(devices, 1):
            print(f"  {i}. {device}")

        while True:
            try:
                choice = input(
                    f"\n{Color.BLUE}Select {device_type_name} (1-{len(devices)}) or 'q' to quit: {Color.NC}"
                ).strip()

                if choice.lower() == "q":
                    return None

                index = int(choice) - 1
                if 0 <= index < len(devices):
                    selected = devices[index]

                    # Ask if user wants to save this choice
                    save_choice = (
                        input(
                            f"{Color.BLUE}Save this as default {device_type_name}? (y/n): {Color.NC}"
                        )
                        .strip()
                        .lower()
                    )
                    if save_choice == "y":
                        self.save_device(platform, is_simulator, selected.udid)
                        print(f"{Color.GREEN}Saved as default{Color.NC}")

                    return selected.udid
                else:
                    print(f"{Color.RED}Invalid selection{Color.NC}")
            except (ValueError, KeyboardInterrupt):
                print(f"\n{Color.YELLOW}Selection cancelled{Color.NC}")
                return None


class BuildRunner:
    def __init__(self, scheme: str = "KMReader", project: str = "KMReader.xcodeproj"):
        self.scheme = scheme
        self.project = project
        self.device_manager = DeviceManager()

    def build(self, platform: str, ci_mode: bool = False) -> bool:
        """Build for the specified platform."""
        # For iOS and tvOS, select simulator for building
        device_udid = None
        if platform.lower() in ("ios", "tvos"):
            # Always use simulator for builds
            is_simulator = True
            device_udid = self.device_manager.select_device(platform, is_simulator)
            if not device_udid:
                print(f"{Color.RED}No device selected{Color.NC}")
                return False

        sdk_map = {
            "ios": "iphonesimulator",
            "macos": "macosx",
            "tvos": "appletvsimulator",
        }

        sdk = sdk_map.get(platform.lower())
        if not sdk:
            print(f"{Color.RED}Unknown platform: {platform}{Color.NC}")
            return False

        print(f"{Color.GREEN}Building for {platform.upper()}...{Color.NC}")

        cmd = [
            "xcodebuild",
            "-project",
            self.project,
            "-scheme",
            self.scheme,
            "-sdk",
            sdk,
            "build",
            "-quiet",
        ]

        # Add destination for device-specific builds
        if device_udid:
            cmd.extend(["-destination", f"id={device_udid}"])
        elif platform.lower() in ("ios", "tvos"):
            # Fallback to generic simulator destination
            cmd.extend(
                ["-destination", f"generic/platform={platform.upper()} Simulator"]
            )
        elif platform.lower() == "macos":
            cmd.extend(["-destination", "platform=macOS"])

        if ci_mode:
            cmd.extend(
                [
                    "CODE_SIGN_IDENTITY=",
                    "CODE_SIGNING_REQUIRED=NO",
                    "CODE_SIGNING_ALLOWED=NO",
                ]
            )

        try:
            subprocess.run(cmd, check=True)
            print(f"{Color.GREEN}{platform.upper()} built successfully!{Color.NC}")
            return True
        except subprocess.CalledProcessError as e:
            print(f"{Color.RED}Build failed: {e}{Color.NC}")
            return False

    def run(
        self,
        platform: str,
        is_simulator: bool,
        device: Optional[str] = None,
        force_select: bool = False,
    ) -> bool:
        """Build and run on the specified platform and device."""
        if platform.lower() == "macos":
            return self._run_macos()

        # Select device
        device_udid = self.device_manager.select_device(
            platform, is_simulator, device, force_select
        )
        if not device_udid:
            print(f"{Color.RED}No device selected{Color.NC}")
            return False

        if is_simulator:
            return self._run_simulator(platform, device_udid)
        else:
            return self._run_device(platform, device_udid)

    def _run_macos(self) -> bool:
        """Build and run on macOS."""
        print(f"{Color.GREEN}Building and running on macOS...{Color.NC}")

        # Build first
        build_cmd = [
            "xcodebuild",
            "-project",
            self.project,
            "-scheme",
            self.scheme,
            "-sdk",
            "macosx",
            "build",
            "-quiet",
        ]

        try:
            subprocess.run(build_cmd, check=True)

            # Find the built app
            result = subprocess.run(
                build_cmd + ["-showBuildSettings"],
                capture_output=True,
                text=True,
                check=True,
            )

            app_path = None
            for line in result.stdout.split("\n"):
                if "BUILT_PRODUCTS_DIR" in line:
                    built_products_dir = line.split("=")[1].strip()
                    app_path = os.path.join(built_products_dir, f"{self.scheme}.app")
                    break

            if app_path and os.path.exists(app_path):
                print(f"{Color.GREEN}Launching {self.scheme}...{Color.NC}")
                subprocess.run(["open", app_path])
                return True
            else:
                print(f"{Color.RED}Could not find built app{Color.NC}")
                return False

        except subprocess.CalledProcessError as e:
            print(f"{Color.RED}Failed to build/run: {e}{Color.NC}")
            return False

    def _run_simulator(self, platform: str, device_udid: str) -> bool:
        """Build and run on simulator."""
        sdk_map = {
            "ios": "iphonesimulator",
            "tvos": "appletvsimulator",
        }

        sdk = sdk_map.get(platform.lower())
        if not sdk:
            print(f"{Color.RED}Unknown platform: {platform}{Color.NC}")
            return False

        print(f"{Color.GREEN}Building for {platform.upper()} simulator...{Color.NC}")

        # Build
        build_cmd = [
            "xcodebuild",
            "-project",
            self.project,
            "-scheme",
            self.scheme,
            "-sdk",
            sdk,
            "-destination",
            f"id={device_udid}",
            "build",
            "-quiet",
        ]

        try:
            subprocess.run(build_cmd, check=True)

            # Get build settings to find app path
            result = subprocess.run(
                build_cmd + ["-showBuildSettings"],
                capture_output=True,
                text=True,
                check=True,
            )

            app_path = None
            for line in result.stdout.split("\n"):
                if "BUILT_PRODUCTS_DIR" in line:
                    built_products_dir = line.split("=")[1].strip()
                    app_path = os.path.join(built_products_dir, f"{self.scheme}.app")
                    break

            if not app_path or not os.path.exists(app_path):
                print(f"{Color.RED}Could not find built app{Color.NC}")
                return False

            # Boot simulator if needed
            print(f"{Color.GREEN}Booting simulator...{Color.NC}")
            subprocess.run(
                ["xcrun", "simctl", "boot", device_udid], stderr=subprocess.DEVNULL
            )  # Ignore error if already booted

            # Install app
            print(f"{Color.GREEN}Installing app...{Color.NC}")
            subprocess.run(
                ["xcrun", "simctl", "install", device_udid, app_path], check=True
            )

            # Get bundle identifier
            bundle_id = self._get_bundle_id(app_path)
            if not bundle_id:
                print(f"{Color.RED}Could not determine bundle identifier{Color.NC}")
                return False

            # Launch app
            print(f"{Color.GREEN}Launching app...{Color.NC}")
            subprocess.run(
                ["xcrun", "simctl", "launch", device_udid, bundle_id], check=True
            )

            print(f"{Color.GREEN}App launched successfully!{Color.NC}")
            return True

        except subprocess.CalledProcessError as e:
            print(f"{Color.RED}Failed to build/run: {e}{Color.NC}")
            return False

    def _run_device(self, platform: str, device_udid: str) -> bool:
        """Build and run on physical device."""
        sdk_map = {
            "ios": "iphoneos",
            "tvos": "appletvos",
        }

        sdk = sdk_map.get(platform.lower())
        if not sdk:
            print(f"{Color.RED}Unknown platform: {platform}{Color.NC}")
            return False

        print(
            f"{Color.GREEN}Building and installing on {platform.upper()} device...{Color.NC}"
        )

        # Build and install
        cmd = [
            "xcodebuild",
            "-project",
            self.project,
            "-scheme",
            self.scheme,
            "-sdk",
            sdk,
            "-destination",
            f"id={device_udid}",
            "build",
            "-quiet",
        ]

        try:
            subprocess.run(cmd, check=True)
            print(
                f"{Color.GREEN}App installed successfully! Launch it manually on your device.{Color.NC}"
            )
            return True
        except subprocess.CalledProcessError as e:
            print(f"{Color.RED}Failed to build/install: {e}{Color.NC}")
            return False

    def _get_bundle_id(self, app_path: str) -> Optional[str]:
        """Extract bundle identifier from app."""
        info_plist = os.path.join(app_path, "Info.plist")
        if not os.path.exists(info_plist):
            return None

        try:
            result = subprocess.run(
                ["defaults", "read", info_plist, "CFBundleIdentifier"],
                capture_output=True,
                text=True,
                check=True,
            )
            return result.stdout.strip()
        except subprocess.CalledProcessError:
            return None


def main():
    parser = argparse.ArgumentParser(
        description="Build and run KMReader on various platforms",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )

    subparsers = parser.add_subparsers(dest="command", help="Command to execute")

    # Build command
    build_parser = subparsers.add_parser("build", help="Build for a platform")
    build_parser.add_argument(
        "platform", choices=["ios", "macos", "tvos"], help="Target platform"
    )
    build_parser.add_argument(
        "--ci", action="store_true", help="CI mode (no code signing)"
    )

    # Run command
    run_parser = subparsers.add_parser("run", help="Build and run on a device")
    run_parser.add_argument(
        "platform", choices=["ios", "macos", "tvos"], help="Target platform"
    )
    run_parser.add_argument(
        "--simulator",
        action="store_true",
        help="Run on simulator (default for iOS/tvOS)",
    )
    run_parser.add_argument(
        "--device", action="store_true", help="Run on physical device"
    )
    run_parser.add_argument("--target", help="Specific device name or UDID")
    run_parser.add_argument(
        "--select",
        action="store_true",
        help="Force device selection prompt even if saved device exists",
    )

    # List devices command
    list_parser = subparsers.add_parser("list", help="List available devices")
    list_parser.add_argument(
        "platform",
        nargs="?",
        choices=["ios", "tvos"],
        help="Platform to list devices for",
    )
    list_parser.add_argument(
        "--simulators", action="store_true", help="List simulators only"
    )
    list_parser.add_argument(
        "--devices", action="store_true", help="List physical devices only"
    )

    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        return 1

    runner = BuildRunner()

    if args.command == "build":
        success = runner.build(args.platform, args.ci)
        return 0 if success else 1

    elif args.command == "run":
        if args.platform == "macos":
            success = runner.run("macos", False)
        else:
            # Default to simulator for iOS/tvOS unless --device is specified
            is_simulator = not args.device if args.device else True
            force_select = args.select if hasattr(args, "select") else False
            success = runner.run(args.platform, is_simulator, args.target, force_select)
        return 0 if success else 1

    elif args.command == "list":
        dm = DeviceManager()

        platforms = [args.platform] if args.platform else ["ios", "tvos"]
        show_sims = args.simulators or not args.devices
        show_devices = args.devices or not args.simulators

        for platform in platforms:
            if show_sims:
                print(f"\n{Color.BLUE}{platform.upper()} Simulators:{Color.NC}")
                sims = dm.list_simulators(platform)
                if sims:
                    for sim in sims:
                        print(f"  {sim}")
                else:
                    print(f"  {Color.YELLOW}No simulators found{Color.NC}")

            if show_devices:
                print(f"\n{Color.BLUE}{platform.upper()} Physical Devices:{Color.NC}")
                devices = dm.list_physical_devices(platform)
                if devices:
                    for device in devices:
                        print(f"  {device}")
                else:
                    print(f"  {Color.YELLOW}No physical devices found{Color.NC}")

        return 0

    return 1


if __name__ == "__main__":
    sys.exit(main())
