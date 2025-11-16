# A simple vim plugin for bugzilla

A Vim plugin for interacting with Bugzilla REST API, inspired by vim-fugitive for ease of navigation.

## Features

### Commands

- `:BugzillaShow <bug_id>` - Display full details of a bug including comments
- `:BugzillaList <search>` - Search and list bugs matching the criteria
- `:BugzillaOpen [<bug_id>]` - Open bug in web browser (uses bug under cursor if ID not provided)

#### BugzillaList Search Syntax

Simple keyword search:
```vim
:BugzillaList memory leak
```

Structured search with fields:
```vim
:BugzillaList status:NEW product:MyProduct
:BugzillaList assignee:user@example.com component:UI
```

### Navigation Keybindings

When viewing a bugzilla buffer (bug details or bug list), the following keybindings are available:

- `<CR>` (Enter) - Open bug under cursor in current window
- `o` - Open bug under cursor in horizontal split
- `O` - Open bug under cursor in new tab
- `gO` - Open bug under cursor in vertical split
- `gb` - Open bug under cursor in web browser
- `q` - Close current bugzilla buffer
- `-` - Navigate back to previous bugzilla buffer
- `?` - Show help with all available keybindings

### Configuration

Set the following in your `.vimrc`:

```vim
" Required: Bugzilla instance URL
let g:bugzilla_url = 'https://bugzilla.example.com'

" Optional: API key for authentication
let g:bugzilla_api_key = 'your_api_key_here'
```

## Requirements

- Vim 8+ or Neovim
- `curl` command line tool
- `jq` command line tool for JSON processing

## Installation

Using [vim-plug](https://github.com/junegunn/vim-plug):

```vim
Plug 'Ethsan/vim-bugzilla'
```

Using [Vundle](https://github.com/VundleVim/Vundle.vim):

```vim
Plugin 'Ethsan/vim-bugzilla'
```

Or manually copy the files to your `~/.vim` directory.

## Usage Examples

1. View a specific bug:
   ```vim
   :BugzillaShow 123456
   ```

2. List bugs with keyword search:
   ```vim
   :BugzillaList crash
   ```

3. Search bugs by status:
   ```vim
   :BugzillaList status:NEW
   ```

4. Navigate through bugs:
   - Use `:BugzillaList` to get a list of bugs
   - Press `<CR>` on any bug to view its details
   - Press `-` to go back to the list
   - Press `q` to close the bugzilla buffer

## License

Copyright © Ethan Milon. Distributed under the same terms as Vim itself. See :help license.
