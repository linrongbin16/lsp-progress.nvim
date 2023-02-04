# Notes

## Design Pattern

Implement with producer/consumer pattern:

- Producer: progress handler is registered to `$/progress`, callback when lsp status updated. Then update progress data and emit event `LspProgressStatusUpdated`.
- Consumer: statusline listens and consumes the event, get the latest progress data and print to statusline.

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

1. Clients: a hash map that mapping lsp client id (`client_id`) to all its messages (here we call them `serieses`).
2. Serieses: a hash map that mapping message token (`token`) to a message (`series`).

## Series(Message) State

Every series(message) under same token have 3 states:

- begin
- report
- end

## Animation Control

### Fixed Spin Rate

The `$/progress` doesn't guarantee when to update the message, but we want a stable animation that keeps spinning. A background job should be created and scheduled at a fixed time, and spin the icon. Use Neovim's `vim.defer_fn` API and Lua's closures.

This also means there's a new producer who emit event: whenever spins(background job schedules), emit an event to let the statusline update its animation.

### Decay Last Message

Lsp status could be really fast(appears and disappears in an instant) even user cannot see it clearly. A decay time should be added to cache the last message for a while.

And still, in decay time, the animation still needs to keep spinning!

## Message Duplication

I have a super large project and when I open a jsx file and type `:w`, I can see 4 more `[null-ls] diagnostics` and `[null-ls] formatting` running!

That duplicated messages seems quite noisy and progress should dedup these messages when formatting.

