# TermHost v5.5

> Delete Website Feature

## New Feature: Delete Website

You can now completely remove a website with one command.

**Menu 4) Delete Website**

This will purge:
- Website directory (`sites/<name>`)
- Virtual host configuration (`vhosts/<name>.conf`)
- hosts entry (`127.0.0.1 <name>.localhost`)
- Automatically reload Nginx

Safety:
- Requires typing `DELETE` to confirm
- Shows exactly what will be removed before proceeding

## Installation

```bash
curl -fsSL https://raw.githubusercontent.com/InetByOu/TermHost/main/install.sh | bash
```

Run:
```bash
termhost
```

## Features

- Delete Website with full purge
- Stable Traditional Menu
- Smart Upgrade
- Change Port (with backup)
- SD Card Hosting
- Termux:Boot & Auto Swap (Root)

## Author
InetByOu