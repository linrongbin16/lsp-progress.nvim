global _: any

global _TEST: boolean

global loadstring: function(string): (function(): any)

global unpack: function<T>({T}, number, number): T...

global getfenv: function(function): table

global record jit
  arch: string
  os: string
  version: string
  version_num: number
  off: function()
  off: function(function)
  on: function()
  status: function(): boolean
end

global vim = require('vim')

global record SeriesRecord
    title: string|nil
    message: string|nil
    percentage: number|nil
    done: boolean
    _formatted: string|any|nil

    tostring: function(SeriesRecord):string
    format: function(SeriesRecord):string|any|nil
    formatted_result: function(SeriesRecord):string|any|nil
    update: function(SeriesRecord, string|nil, number|nil):nil
    finish: function(SeriesRecord, string|nil):nil
end

global record ClientRecord
    id: number|nil
    name: string|nil
    spin_index: integer
    serieses: {string:SeriesRecord}
    _formatted: string|any|nil
    _deduped_tokens: {string:{string:string}}

    formatted_result: function(ClientRecord):string|any|nil
    tostring: function(ClientRecord):string
    has_series: function(ClientRecord, string):boolean
    get_series: function(ClientRecord, string):SeriesRecord
    format: function(ClientRecord):string|any|nil
    _has_deduped_token: function(ClientRecord, string|nil, string|nil):boolean
    _set_deduped_token: function(ClientRecord, string|nil, string|nil, token:string|nil):nil
    _remove_deduped_token: function(ClientRecord, string|nil, string|nil):nil
    _get_deduped_token: function(ClientRecord, string|nil, string|nil):string
    remove_series: function(ClientRecord, string|nil):nil
    add_series: function(ClientRecord, string|nil, SeriesRecord):nil
    empty: function(ClientRecord):boolean
    increase_spin_index: function(ClientRecord):nil
end

global type SeriesRecordFormatterType = function(string|nil,string|nil,number|nil,boolean|nil):string|any|nil
global type ClientRecordFormatterType = function(string|nil,string|nil,{string|any}):string|any|nil
