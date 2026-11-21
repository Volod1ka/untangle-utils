<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/assets/untangle/logo-dark-bg.svg">
    <img src="docs/assets/untangle/logo-light-bg.svg" width="220" alt="UnTangle logo">
  </picture>
</p>

<h1 align="center">UnTangle</h1>

<p align="center">
  A personal macOS menu bar toolkit.<br>
  An unofficial fork of <a href="https://github.com/vorssaint/vorssaint-utils">Vorssaint</a>.
</p>

<p align="center">
  <a href="#what-you-need"><img src="https://img.shields.io/badge/macOS-14%2B%20Apple%20Silicon-black" alt="macOS 14 and newer, Apple Silicon"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-GPL--3.0--or--later-blue" alt="License GPL 3.0 or later"></a>
</p>

## About this fork

UnTangle is a modified version of [Vorssaint](https://github.com/vorssaint/vorssaint-utils),
a free, open-source set of menu bar utilities for macOS. It is **not affiliated with,
endorsed by or supported by** the Vorssaint project or its maintainer. Please do not
report UnTangle problems to the original project.

As [TRADEMARKS.md](TRADEMARKS.md) asks of forks, UnTangle uses its own name, icon,
bundle identifier (`com.volod1ka.untangle`), signing identity and update policy. What
differs from the original:

- **Name and icon.** Everything the app shows says UnTangle, with its own mark and icon.
- **No update feed.** UnTangle never downloads releases; it is built from source.
- **No upstream services.** The feedback form, donation page and release showcase of
  the original project are hidden, so nothing is sent to its servers.
- **Separate system state.** Preferences, data folders, the closed-lid sudoers rule and
  the fan helper all use UnTangle's own identifiers, so it can sit next to the original
  app without either touching the other.

Features, privacy notes and permissions are otherwise the same as upstream. See the
[original README](https://github.com/vorssaint/vorssaint-utils#readme) and the
[docs](docs/) for the full feature list.

## What you need

- A Mac with Apple Silicon
- macOS 14 Sonoma or newer
- Xcode Command Line Tools

## Build and install

```sh
git clone https://github.com/Volod1ka/untangle-utils.git
cd untangle-utils
Tools/setup-signing.sh        # once: creates the local "UnTangle Signing" identity
./build.sh --dev --install    # "UnTangle (Developer)", for trying changes
./build.sh --install          # "UnTangle"
./build.sh --test             # test suite
```

The signing identity keeps the code signature stable between builds, so macOS keeps
the permissions you grant (Accessibility, Screen Recording and so on).

## Uninstall

```sh
./Tools/uninstall.sh
```

## Staying in sync with upstream

`main` mirrors the original repository, and UnTangle's changes live on `develop`:

```sh
git checkout main && git fetch upstream && git merge --ff-only upstream/main
git checkout develop && git merge main
```

New user-facing text from upstream will say "Vorssaint" until it is renamed here.

## License

[GPL 3.0 or later](LICENSE). Original work copyright 2026 Vorssaint; modifications in
this fork by Volod1ka, under the same license. The Vorssaint name, logo and look belong
to their owner and are covered by [TRADEMARKS.md](TRADEMARKS.md); they are not used by
this fork except to credit the original project.
