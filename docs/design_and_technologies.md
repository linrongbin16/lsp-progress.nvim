# Design & Technologies

## The [`$/progress`](https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#progress) Method

This plugin registers the `$/progress` method into Neovim's [vim.lsp.handlers](https://neovim.io/doc/user/lsp.html#vim.lsp.handlers) table (or use the `LspProgress` event for Neovim v0.10+). Once there's any lsp progress messages, the registered callback function will be invoked.

Here I use the [Producer-Consumer Pattern](https://en.wikipedia.org/wiki/Producer%E2%80%93consumer_problem) to split the data processing and UI rendering into two parts:

- Producer: The lua function that registers on `$/progress` method (or `LspProgress` event). It receives lsp progress messages and saves in plugin context, then produces a user event to notify.
- Consumer: A Vim `autocommand` that listens to the user event, consumes the lsp progress messages, prints to UI component, for example the statusline.

That's why I provide two APIs:

- `setup`: It registers a lua callback `function(err, msg, ctx)` on `$/progress` method (or `LspProgress` event).
- `progress`: It consumes the lsp progress messages, and returns the final rendered text contents.

And one user event:

- `User LspProgressStatusUpdated`: When there's a lsp progress message, this plugin will emit this event to notify users.

## Data Structures

A Vim buffer (the file you're editing) can have multiple lsp cilents, each lsp client can have multiple progress messages (each message has a unique token), each message is a time-based data series from beginning to end, i.e. the _**progress**_.

Based on this scenario, we have a 2-layer hash table:

<img width="80%" alt="image" src="https://github.com/linrongbin16/lsp-progress.nvim/assets/6496887/02344d8d-1503-48aa-bc35-2db9914e5866">

The layer-1 maps from a client ID to a client instance, the layer-2 maps from a unique token to a message instance, i.e. the _**series**_.

## Performance

Formatting the 2-layer hash table is a **O(N \* M)** time complexity calculation.

?> **N** is the active client count, **M** is the unique token count.

If we format the messages right before the statusline refreshing, it can lead to editor blocking if the data is too big. It actually happened to me, since I installed over 10+ lsp servers and 5+ code formatters, linters, etc through none-ls, for the super large git monorepo (much bigger than [linux kernel](https://github.com/torvalds/linux)) that belongs to the company I'm working for, it contains over 10+ programming languages.

There're 3 steps to optimize:

1. Add format cache on both message instances and client instances (the _**red**_ parts):

   <img width="80%" alt="image" src="https://github.com/linrongbin16/lsp-progress.nvim/assets/6496887/3286cb60-2b57-47df-8008-53161587bf6a">

2. Split the **O(N \* M)** calculation into each message's updating. Every time a message receives updates, it will:

   1. On message instance, it invokes the `series_format` function to format the lsp message and cache to its `formatted` variable.
   2. On client instance, it invokes the `client_format` function to concatenate multiple `formatted` caches and cache to its `formatted` variable.

3. When statusline refreshing, the `progress` API invokes the `format` function to concatenate multiple client instances `formatted` caches and returns a final result, which is quite cheap and fast.

## Customization

There're 3 formatting hook functions that maximize the customization. From bottom to top they are:

### `series_format`

```lua
--- @param title string?
---     Message title.
--- @param message string?
---     Message body.
--- @param percentage integer?
---     Progress in percentage numbers: 0-100.
--- @param done boolean
---     Indicate whether this series is the last one in progress.
--- @return lsp_progress.SeriesFormatResult
---     The returned value will be passed to function `client_format` as
---     one of the `series_messages` array, or ignored if return nil.
series_format = function(title, message, percentage, done)
```

It formats the message level data. The returned value will be passed to next level `client_format` function, as one of `series_messages` array parameter.

By default the result looks like:

```
formatting isort (100%) - done
formatting black (50%)
```

### `client_format`

```lua
--- @param client_name string
---     Client name.
--- @param spinner string
---     Spinner icon.
--- @param series_messages string[]|table[]
---     Messages array.
--- @return lsp_progress.ClientFormatResult
---     The returned value will be passed to function `format` as one of the
---     `client_messages` array, or ignored if return nil.
client_format = function(client_name, spinner, series_messages)
```

It formats the client level data, the parameter `series_messages` is an array, each of them is returned from `series_format`. The returned value will be passed to next level `format` function, as one of `client_messages` array parameter.

By default the result looks like:

```
[null-ls] ⣷ formatting isort (100%) - done, formatting black (50%)
```

### `format`

```lua
--- @param client_messages string[]|table[]
---     Client messages array.
--- @return string
---     The returned value will be returned as the result of `progress` API.
format = function(client_messages)
```

It formats the top level data, the parameter `client_messages` is an array, each of them is returned from `client_format`. The returned value will be passed as the result of `progress` API.

By default the result looks like:

```
 LSP [null-ls] ⣷ formatting isort (100%) - done, formatting black (50%)
```

!> There's no such requirements that these formatting functions have to return a `string` type. Actually you can return any type, for example `table`, `array`, `number`. But `nil` value will be ignored and throw away.

## Other Enhancements

### Spinning Animation

The `$/progress` method doesn't guarantee when to update, but user may want an accurate spinning animation, i.e. the `⣷` icon keeps spinning in a fixed rate. A background job is scheduled and runs within a fixed interval time to update the spin icon.

### Delayed Disappearance

A lsp progress message can be really fast, appears and disappears in an instant, and people cannot even see it. A delayed timeout is been set to cache the last message for a while. During this while, the spinning animation still needs to keep running!

### Message Deduplication

Again in the super large git monorepo, I have seen 4+ duplicated `formatting (100%)` and `diagnostics (100%)` messages showing at the same time, when I work with `eslint`, `prettier` (via `none-ls`) and `flow`. Turns out they come from the multiple processes launched by the `flow-cli` in background, which is quite noisy.

So I introduced another hash table (maps `title+message` to `token`) to detect the duplicates and reduce them.
