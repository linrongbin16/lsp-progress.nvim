# Notes

## Design Pattern

Implement with a producer/consumer pattern:

- Producer: progress handler is registered to `$/progress`, callback when lsp status updated. Then update status data and emit event `LspProgressStatusUpdated`.
- Consumer: statusline listens and consumes the event, get the latest status data, format and print to statusline.

## Data Structure

A buffer could have multiple active lsp clients. Each client could have multiple messages. Every message should be a data series over time, from beginning to end.

There're two hash maps based on this situation:

```
                    clients:
                    /      \
            (client_id1)  (client_id2)
                  /          \
                tasks        ...
                /   \
          (token1)  (token2)
              /       \
           task1      task2
```

1. Clients: a hash map that mapping from lsp client id (`client_id`) to all its series messages, here we call them tasks.
2. Tasks: a hash map that mapping from a message token (`token`) to a unique message.

## Message State

Every message should have 3 states (belong to same token):

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
