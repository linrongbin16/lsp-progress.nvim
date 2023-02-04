# Notes

## Produce/Consumer Pattern

- Producer: progress handler registers to `$/progress`, being callback when lsp status updated. Then updates progress data and emits an event `LspProgressStatusUpdated`.
- Consumer: statusline listens and consumes the event, gets the latest progress data and prints to statusline.

## Data Structure

A buffer can have multiple active lsp clients. Each client can have multiple messages. Every message is a data series over time, from beginning to end.

There're two hash maps based on this situation:

```
                clients (client_id => client)
                /      \
           client1    client2 (token => serieses)
          /      \
      series1    series2
```

1. Clients: a hash map that maps a lsp client id (`client_id`) to its messages (here we call them `serieses`).
2. Serieses: a hash map that maps a message token (`token`) to a message (`series`).

## Series(Message) State

Every series(message) belong to the same token has 3 states:

- begin
- report
- end

## Animation Control

### Fixed Spin Rate

The `$/progress` doesn't guarantee when to update the message, but we want a stable animation that keeps spinning. A background job is created and scheduled at a fixed time, and spined the icon. Implement with Neovim's `vim.defer_fn` API and Lua's closures.

This also means there's a new producer who emit event: whenever spin(background job schedules), emit an event to let the statusline update its animation.

### Decay Last Message

Lsp status can be really fast(appear and disappear in an instant) even user cannot see it clearly. A decay time is added to cache the last message for a while.

And still, in decay time, the animation still needs to keep spinning!

## Message Duplication

A super large react project can have 4 or more `[null-ls] diagnostics` and `[null-ls] formatting` running at same time!

That's quite noisy, `progress` API dedups these messages when formatting.

