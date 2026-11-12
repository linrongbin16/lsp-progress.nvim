local cwd = vim.fn.getcwd()

describe("lsp-progress", function()
    local assert_eq = assert.is_equal
    local assert_true = assert.is_true
    local assert_false = assert.is_false

    local lsp_progress = require("lsp-progress")

    -- The plugin is guarded by `vim.g.loaded_lsp_progress` and refuses to be
    -- loaded twice, the tests below need a fresh instance for each case.
    local function setup(option)
        vim.g.loaded_lsp_progress = nil
        lsp_progress.setup(option)
    end

    before_each(function()
        vim.api.nvim_command("cd " .. cwd)
        setup()
    end)

    describe("[LspClients]", function()
        it("progress", function()
            assert_eq(type(lsp_progress.progress()), "string")
        end)
        it("add/remove", function()
            lsp_progress._register_client(1, "lua_ls")
            assert_true(lsp_progress._has_client(1))
            local cli = lsp_progress._get_client(1)
            assert_eq(type(cli), "table")
            assert_eq(cli.client_id, 1)
            assert_eq(cli.client_name, "lua_ls")
            assert_false(lsp_progress._has_client(2))
            lsp_progress._remove_client(1)
            assert_false(lsp_progress._has_client(1))
            assert_false(lsp_progress._has_client(2))
            lsp_progress._register_client(2, "null-ls")
            assert_true(lsp_progress._has_client(2))
            assert_false(lsp_progress._has_client(1))
        end)
    end)

    local function utf8_validate(s)
        local i = 1
        while i <= #s do
            local b = s:byte(i)
            local len
            if b < 128 then
                len = 1
            elseif b >= 194 and b <= 223 then
                len = 2
            elseif b >= 224 and b <= 239 then
                len = 3
            elseif b >= 240 and b <= 247 then
                len = 4
            else
                return false
            end
            if i + len - 1 > #s then
                return false
            end
            for j = i + 1, i + len - 1 do
                local c = s:byte(j)
                if c < 128 or c > 191 then
                    return false
                end
            end
            i = i + len
        end
        return true
    end

    describe("[truncate]", function()
        local truncate = lsp_progress._truncate
        local cjk = string.rep("\228\184\173", 100) -- 100 CJK chars, width 200
        local braille = "\226\163\190" -- "⣾", the default spinner icon

        it("returns content unchanged when display width fits", function()
            assert_eq(truncate("", 40), "")
            assert_eq(truncate(string.rep("a", 40), 40), string.rep("a", 40))
            assert_eq(truncate(braille .. "abc", 5), braille .. "abc")
        end)

        it("keeps CJK when bytes exceed but width fits", function()
            local s = string.rep("\228\184\173", 20) -- 60 bytes, width 40
            assert_eq(truncate(s, 40), s)
            assert_eq(truncate(s, 41), s)
        end)

        it("truncates ascii on width budget with ellipsis", function()
            local r = truncate(string.rep("a", 200), 40)
            assert_eq(r, string.rep("a", 39) .. "…")
            assert_eq(vim.fn.strdisplaywidth(r), 40)
        end)

        it("never splits multi-byte characters", function()
            for _, max in ipairs({ 1, 2, 3, 4, 5, 8, 13 }) do
                local r = truncate(braille .. "abcdef", max)
                assert_true(utf8_validate(r))
                assert_true(vim.fn.strdisplaywidth(r) <= math.max(max, 1))
            end
            local r = truncate(cjk, 40)
            assert_true(utf8_validate(r))
            assert_eq(vim.fn.strdisplaywidth(r), 39) -- 19 CJK + "…"
        end)

        it("handles tiny max_size without invalid UTF-8", function()
            assert_eq(truncate("abc", 0), "…")
            assert_eq(truncate(braille .. "abc", 1), "…")
            assert_eq(truncate(braille .. "abc", 2), braille .. "…")
        end)

        it("measures tab width in prefix context", function()
            local r = truncate("a\tb", 9)
            assert_true(utf8_validate(r))
            assert_true(vim.fn.strdisplaywidth(r) <= 9)
            -- tab alone is 8 columns; "a" + tab = 9 fits exactly
            assert_eq(truncate("a\tb", 10), "a\tb")
        end)

        it("handles C1 control characters rendered wider than bytes", function()
            local s = "x\u{80}y" -- U+0080 renders as "<80>" (4 columns)
            local r = truncate(s, 5)
            assert_true(utf8_validate(r))
            assert_true(vim.fn.strdisplaywidth(r) <= 5)
        end)

        it("truncates mixed multi-byte and ascii content", function()
            local s = string.rep("\228\184\173", 50) .. string.rep("a", 50)
            local r = truncate(s, 60)
            assert_true(utf8_validate(r))
            assert_true(vim.fn.strdisplaywidth(r) <= 60)
            assert_true(r:find("…", 1, true) ~= nil)
        end)
    end)

    describe("[max_size]", function()
        -- Drive the real progress() path: stub the LSP client list so the
        -- default format renders. Adding a series marks the client dirty, so
        -- the following read already reflects it, no matter the tick.
        local api = require("lsp-progress.api")
        local real_lsp_clients = api.lsp_clients
        local real_ambiwidth

        before_each(function()
            real_ambiwidth = vim.o.ambiwidth
            api.lsp_clients = function()
                return { { id = 1, name = "stub" } }
            end
        end)

        after_each(function()
            api.lsp_clients = real_lsp_clients
            vim.o.ambiwidth = real_ambiwidth
            lsp_progress._remove_client(1)
            setup()
        end)

        local function render(max_size, message)
            setup({ max_size = max_size })
            lsp_progress._register_client(1, "stub")
            local cli = lsp_progress._get_client(1)
            cli:add_series("tok", {
                title = "t",
                message = message,
                format_result = function()
                    return message
                end,
            })
            return lsp_progress.progress()
        end

        it("keeps multi-byte spinner intact when truncating", function()
            local msg = "\226\163\190 " .. string.rep("x", 100)
            local r = render(10, msg)
            -- default format prefix: " LSP [stub] ⣾ " then message
            assert_true(utf8_validate(r))
            assert_true(vim.fn.strdisplaywidth(r) <= 10)
            assert_true(r:find("…", 1, true) ~= nil)
        end)

        it("leaves content unchanged under max_size", function()
            local r = render(200, "short")
            assert_true(r:find("short", 1, true) ~= nil)
            assert_eq(r:find("…", 1, true), nil)
        end)

        it("disables truncation when max_size is -1", function()
            local r = render(-1, string.rep("x", 500))
            assert_eq(r:find("…", 1, true), nil)
        end)
    end)

    describe("[nil guard]", function()
        local progress_obj = {
            token = "tok",
            value = { kind = "begin", title = "t", message = "m" },
        }

        local function ev(client_id, value)
            return {
                data = {
                    client_id = client_id,
                    params = { token = "tok", value = value },
                },
            }
        end

        it("update_progress ignores nil client", function()
            assert.has_no.errors(function()
                lsp_progress._update_progress(nil, progress_obj)
            end)
            assert_false(lsp_progress._has_client(99999))
        end)

        it("method_handler ignores unknown client id", function()
            assert.has_no.errors(function()
                lsp_progress._method_handler(
                    nil,
                    progress_obj,
                    { client_id = 99999 }
                )
            end)
            assert_false(lsp_progress._has_client(99999))
        end)

        it("event_handler ignores unknown client id", function()
            assert.has_no.errors(function()
                lsp_progress._event_handler(ev(99999, progress_obj.value))
            end)
            assert_false(lsp_progress._has_client(99999))
        end)

        it("event_handler ignores malformed events", function()
            assert.has_no.errors(function()
                lsp_progress._event_handler(nil)
                lsp_progress._event_handler({})
                lsp_progress._event_handler({ data = {} })
            end)
        end)

        it("still processes progress for a live client", function()
            local real_get = vim.lsp.get_client_by_id
            vim.lsp.get_client_by_id = function(id)
                if id == 77 then
                    return { id = 77, name = "stub" }
                end
                return real_get(id)
            end
            local ok, err = pcall(function()
                lsp_progress._event_handler(ev(77, {
                    kind = "begin",
                    title = "t",
                    message = "m",
                    percentage = 10,
                }))
                assert_true(lsp_progress._has_client(77))
                local cli = lsp_progress._get_client(77)
                assert_true(cli:has_series("tok"))
                lsp_progress._event_handler(ev(77, {
                    kind = "report",
                    message = "m2",
                    percentage = 40,
                }))
                assert_eq(cli:get_series("tok").percentage, 40)
                lsp_progress._event_handler(ev(77, {
                    kind = "end",
                    message = "done",
                }))
                assert_true(cli:get_series("tok").done)
            end)
            vim.lsp.get_client_by_id = real_get
            lsp_progress._remove_client(77)
            if not ok then
                error(err)
            end
        end)
        it("keeps percentage when a report omits it", function()
            local real_get = vim.lsp.get_client_by_id
            vim.lsp.get_client_by_id = function(id)
                if id == 78 then
                    return { id = 78, name = "stub" }
                end
                return real_get(id)
            end
            local ok, err = pcall(function()
                lsp_progress._event_handler(ev(78, {
                    kind = "begin",
                    title = "t",
                    message = "m",
                    percentage = 40,
                }))
                local cli = lsp_progress._get_client(78)
                assert_eq(cli:get_series("tok").percentage, 40)

                -- 'percentage' is optional in the LSP spec: a report without
                -- it must not reset the progress that is already displayed.
                lsp_progress._event_handler(ev(78, {
                    kind = "report",
                    message = "m2",
                }))
                local ss = cli:get_series("tok")
                assert_eq(ss.message, "m2")
                assert_eq(ss.percentage, 40)

                lsp_progress._event_handler(ev(78, {
                    kind = "report",
                    message = "m3",
                    percentage = 70,
                }))
                assert_eq(cli:get_series("tok").percentage, 70)
            end)
            vim.lsp.get_client_by_id = real_get
            lsp_progress._remove_client(78)
            if not ok then
                error(err)
            end
        end)
    end)
    describe("[setup]", function()
        it("only loads the plugin once", function()
            if vim.fn.has("nvim-0.10") <= 0 then
                return
            end
            setup()
            local count = #vim.api.nvim_get_autocmds({ event = "LspProgress" })
            lsp_progress.setup()
            lsp_progress.setup()
            assert_eq(
                #vim.api.nvim_get_autocmds({ event = "LspProgress" }),
                count
            )
        end)
        it("ignores the options of a repeated call", function()
            local api = require("lsp-progress.api")
            local real_lsp_clients = api.lsp_clients
            api.lsp_clients = function()
                return { { id = 1, name = "stub" } }
            end

            setup({ max_size = 10 })
            lsp_progress.setup({ max_size = -1 })

            -- the second call is ignored, so the truncation stays enabled
            lsp_progress._register_client(1, "stub")
            local cli = lsp_progress._get_client(1)
            cli:add_series("tok", {
                title = "t",
                message = string.rep("x", 100),
                format_result = function()
                    return string.rep("x", 100)
                end,
            })
            local content = lsp_progress.progress()

            lsp_progress._remove_client(1)
            api.lsp_clients = real_lsp_clients
            assert_true(content ~= "")
            assert_true(vim.fn.strdisplaywidth(content) <= 10)
        end)
    end)
end)
