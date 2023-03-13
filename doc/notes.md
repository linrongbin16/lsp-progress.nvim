# Notes

## Producer/Consumer Pattern

- Producer: progress handler is registered to `$/progress`, being called back
  when lsp status updated. Then updates progress data and emits an event `LspProgressStatusUpdated`.
- Consumer: statusline listens and consumes the event, gets the latest progress
  data and prints to statusline.

## Data Structure

In setup configuration, there're several **format** functions that are related to internal
implementations and may confuse you.

Basically, a vim buffer(the file you edit) can have multiple active lsp clients.
Each client can have multiple messages with unique tokens. Every message is a
data series over time, from beginning to end.

Here we have two hash maps based on this situation:

```text
                    Clients (client_id => client)
                   /        \
          client1:Serieses  client2:Serieses (token => serieses)
                  /      \
             series1    series2
```

1. Clients: a hash map that maps a lsp client id (`client_id`) to its messages
   (here we call them `Serieses`).
2. Serieses: a hash map that maps a message token (`token`) to a message (`series`).

## Fixed Spin Rate Animation

The `$/progress` doesn't guarantee when to update the message, but we want a
stable animation that keeps spinning. A background job is created and scheduled
at a fixed time, and spined the icon. Implement with Neovim's `vim.defer_fn` API
and Lua closure.

This also means there's a new producer who emit event: whenever spin(background
job schedules), emit an event to let the statusline update its animation.

## Decay Last Message

Lsp status can be really fast(appear and disappear in an instant) even you
cannot see it clearly. A decay time is added to cache the last message for a while.

And still, in decay time, the animation still needs to keep spinning!

## Message Duplication

At one time, in one of my super large react project, I have seen 4 more
`[null-ls] diagnostics` and `[null-ls] formatting` messages running at the same
time! That's quite noisy, so I reduced the duplicate messages when formatting them
in `progress` function.
