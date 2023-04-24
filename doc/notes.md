# Notes

## Producer/Consumer Pattern

- Producer: the progress handler is registered to `$/progress`, callback when lsp
  status is updated, and emits an event `LspProgressStatusUpdated`.
- Consumer: the statusline listens the event and gets the latest progress data and
  prints to statusline.

## Data Structure

Basically, a vim buffer(the file you edit) can have multiple active lsp clients.
Each client can have multiple messages with unique tokens. Every message is a data
series over time, from beginning to end.

Here we have two hash maps based on this situation:

```text
                   LspClients (client_id => client)
                   /        \
          client1:Serieses  client2:Serieses (token => serieses)
                  /      \
             series1    series2
```

1. LspClients: a hash map that maps a lsp client id (`client_id`) to its messages
   (here we call them `Serieses`).
2. Serieses: a hash map that maps a message token (`token`) to a message (`series`).

## Fixed Spin Rate Animation

The `$/progress` doesn't guarantee when to update the message, but we want a stable
animation that keeps spinning in a fixed time internal. Thus a background job is
created and scheduled to spin the icon at a fixed time internal. Implement with
Neovim's `vim.defer_fn` API and Lua closure.

Which means there's a new producer who emits event: whenever the background job spins,
it emits an event to notify the statusline to update animation.

## Decay Last Message

Lsp status can be really fast(appear and disappear in an instant) even user cannot
see it clearly. A decay time is added to cache the last message for a while. And
yes, the animation still needs to keep spinning in the decay time!

## Message Duplication

In one of my super large react project, I've seen 4 more `[null-ls] diagnostics`
and `[null-ls] formatting` messages running at the same time! That's quite noisy,
so these duplicate messages are been removed.
