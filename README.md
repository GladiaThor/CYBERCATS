# CYBERCATS

**Your terminal. Your tools. Different corporate nonsense.**

CYBERCATS is a modular, cross-platform terminal configuration for macOS, Linux and WSL. Built around a consistent visual identity, reusable powers and a streamlined setup, it delivers a familiar development environment regardless of whatever bullshit OS your enterprise throws your way.

CYBERCATS came to be for a few reasons. I used to be a consultant and had multiple machines at any given time. And over the years I've had to maintain a working dev environment across my home servers, cloud servers, MacBooks, Windows PC (yes singular), Linux machines, refrigerators, etc. If it had a computer in it, I've had to maintain something on it and there is nothing worse than having to set up a new machine in a new place and having it look and feel different from what I'm used to. Especially the terminal. Dotfile repos felt too minimalistic, and I just wanted something a little more. (Also, I really love reinventing the wheel, apparently.) So, one cold winter day in 2017, I started building what has now become CYBERCATS. It has since survived 15 different machines and a few different operating systems. This time, I actually took the time to iron out the last of the kinks and make it user-friendly so others could enjoy it too.

The idea is simple: your development environment should belong to you, not to the operating system you're currently unfortunate enough to be using.

## Philosophy

A good development environment should be familiar, portable and easy to maintain. Setting up a new machine shouldn't require remembering years of shell customisations, reinstalling your favourite tools by hand or spending an afternoon persuading the terminal to look vaguely acceptable.

So our core principles are:

- **One environment, regardless of operating system.**
- **Modular by design.** Install the tools and capabilities you actually want.
- **Configuration as code.** Keep the environment reproducible, inspectable and version-controlled.
- **A consistent identity.** The same colours, fonts, conventions and familiar shell experience everywhere.
- **Minimal ceremony.** Sensible defaults, straightforward installation and no unnecessary framework around something that should be simple.

## What's Inside?

### The CYBERCATS Shell

CYBERCATS uses Zsh as its primary shell, with a common runtime responsible for loading configuration, visual elements and powers. The shell environment is designed to remain consistent across supported platforms while keeping platform-specific behaviour isolated wherever possible.

### Powers

Powers are something between an alias and a full-blown application. They're modular extensions that add commands and capabilities to CYBERCATS. They're easy to build, and the `ccpowers` framework makes building your own even easier.

**Builtin powers** are distributed and maintained as part of CYBERCATS. **Installed powers** extend the environment independently.

### Terminal and Appearance

CYBERCATS uses a shared visual identity with a soft, colourful palette built around its signature rose, pink, lavender, mauve, sky, cyan, mint and peach tones.

The recommended terminal is **Ghostty**, with **IBM BlexMono Nerd Font Mono** providing a consistent monospaced font and Nerd Font glyph support.

Ghostty also supports terminal graphics, making inline imagery and rendered diagrams possible through compatible applications. Because, as an architect who hates PowerPoint, I need to keep my diagrams somewhere that isn't in a browser.

The terminal is a recommendation, not a prison. CYBERCATS' shell and powers should remain usable in other compatible terminals.

### Development Tools

CYBERCATS aims to provide a consistent toolchain across operating systems, using Homebrew as the common package-management layer where practical. Some components still require platform-specific installation, but those differences should be handled by installation scripts rather than becoming the user's problem.

## Installation

Clone the CYBERCATS repository and run its installer:

```bash
git clone https://github.com/GladiaThor/CYBERCATS
cd <repository-directory>
bash install.sh
```

> [!WARNING]
> The installer archives your existing `.config`, and `.zshrc` configuration. You'll need to merge your existing customisations manually the first time.

The installer handles the initial setup and lets you choose optional components, including Ghostty.

CYBERCATS deploys its runtime into:

```text
~/.cybercats/
```

Your shell loads the installed runtime from there. The installation is deliberately separate from the Git repository, so you don't need to keep the original checkout around.


## Architecture

The installed CYBERCATS runtime follows a modular layout:

```text
.cybercats/
├── main.zsh
├── revision
├── visual/
└── powers/
    ├── src/
    │   └── <power>/
    │       ├── power.toml
    │       └── ...
    ├── builtins/
    └── installed/
```

`main.zsh` initialises CYBERCATS, `visual/` contains shared visual functionality, and `powers/` contains the extension system.

Each power can provide its own metadata and implementation, keeping the core relatively small.

## Updating CYBERCATS

CYBERCATS includes a self-updating builtin power.

**Check whether a newer version is available:**

```bash
ccupdate --check
```

**Install the latest version:**

```bash
ccupdate
```

CYBERCATS uses Git revisions rather than manually maintained version numbers. The installed revision is recorded in:

```text
~/.cybercats/revision
```

A lightweight update check can run during terminal startup, notifying you when an update is available without automatically installing it.

Updates target the CYBERCATS-managed runtime components:

- `main.zsh`
- `visual/`
- Builtin powers and their corresponding source files
- The installed revision record

Independently installed powers and other user configuration remain outside the normal update scope.

After updating, start a new shell session to load the updated definitions.

## Extending CYBERCATS

The powers system is intended to make extensions easy to develop and distribute.

A power has its own directory and metadata, allowing the runtime to recognise and load its functionality without turning the main shell configuration into a maintenance nightmare.

Over time, CYBERCATS can support additional powers for development tools, automation, productivity and whatever else makes living in a terminal more enjoyable.

## Platform Support

| Platform | Status |
| --- | --- |
| macOS | Primary target |
| Linux | Supported target |
| WSL | Supported target |
| Native Windows | No |

I don't respect an OS that doesn't respect the user. So CYBERCATS is designed for Unix-like environments. WSL provides that environment on Windows.

Platform-specific tools and package availability may differ. Check Homebrew for your OS before comitting to CYBERCATS.

## Project Status

CYBERCATS is evolving. The core runtime, visual configuration, powers architecture and installation experience are being developed together. Some functionality may change as I port more powers over (because I have hundreds) and as the project matures. The goal isn't to accumulate features for the sake of features, but to create an environment that remains useful, understandable and pleasant to work with.

One feature I'm working on is making the portability aspect a little more user-friendly and less copy-and-paste.

Contributions, experiments and sensible improvements are always welcome.

## TL;DR

Your development environment should be the one part of your working day that behaves exactly the way you expect it to, no matter which computer you happen to turn on that day. This helps with that.
