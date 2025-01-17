local log = require('distant.log')

--- @class AuthHandler
--- @field finished boolean #true if handler has finished performing authentication
local AuthHandler = {}
AuthHandler.__index = AuthHandler

--- Creates a new instance of the authentication handler.
--- @return AuthHandler
function AuthHandler:new()
    local instance = {}
    setmetatable(instance, AuthHandler)
    return instance
end

--- Returns true if the provided message with a type is an authentication request.
--- @param msg {type:string}
--- @return boolean
function AuthHandler:is_auth_msg(msg)
    return msg and type(msg.type) == 'string' and vim.tbl_contains({
        'auth_initialization',
        'auth_start_method',
        'auth_challenge',
        'auth_verification',
        'auth_info',
        'auth_error',
        'auth_finished',
    }, msg.type)
end

--- Processes some message as an authentication request.
--- @param msg table #incoming request message
--- @param reply fun(msg:table) #used to send a response message back
--- @return boolean #true if okay, otherwise false to indicate error/unknown
function AuthHandler:handle_msg(msg, reply)
    local type = msg.type

    if type == 'auth_initialization' then
        reply({
            type = 'auth_initialization_response',
            methods = self:on_initialization(msg)
        })
        return true
    elseif type == 'auth_start_method' then
        self:on_start_method(msg.method)
        return true
    elseif type == 'auth_challenge' then
        reply({
            type = 'auth_challenge_response',
            answers = self:on_challenge(msg)
        })
        return true
    elseif type == 'auth_info' then
        self:on_info(msg.text)
        return true
    elseif type == 'auth_verification' then
        reply({
            type = 'auth_verification_response',
            valid = self:on_verification(msg)
        })
        return true
    elseif type == 'auth_error' then
        self:on_error(vim.inspect(msg))
        return false
    elseif type == 'auth_finished' then
        self:on_finished()
        return true
    else
        self:on_unknown(msg)
        return false
    end
end

--- Invoked when authentication is starting, containing available methods to use for authentication.
--- @param msg {methods:string[]}
--- @return string[] #authentication methods to use
function AuthHandler:on_initialization(msg)
    return msg.methods
end

--- Invoked when an indicator that a new authentication method is starting during authentication.
--- @param method string
function AuthHandler:on_start_method(method)
    log.fmt_trace('Beginning authentication method: %s', method)
end

--- Invoked when a request to answer some questions is received during authentication.
--- @param msg {questions:{text:string, extra:table<string, string>|nil}[], extra:table<string, string>|nil}
--- @return string[]
function AuthHandler:on_challenge(msg)
    if msg.extra then
        if msg.extra.username then
            print('Authentication for ' .. msg.extra.username)
        end
        if msg.extra.instructions then
            print(msg.extra.instructions)
        end
    end

    local answers = {}
    for _, question in ipairs(msg.questions) do
        if question.extra and question.extra.echo == 'true' then
            table.insert(answers, vim.fn.input(question.text))
        else
            table.insert(answers, vim.fn.inputsecret(question.text))
        end
    end
    return answers
end

--- Invoked when a request to verify some information is received during authentication.
--- @param msg {kind:'host'|'unknown', text:string}
--- @return boolean
function AuthHandler:on_verification(msg)
    local answer = vim.fn.input(string.format('%s\nEnter [y/N]> ', msg.text))
    if answer ~= nil then
        answer = vim.trim(answer)
    end
    return answer == 'y' or answer == 'Y' or answer == 'yes' or answer == 'YES'
end

--- Invoked when information is received during authentication.
--- @param text string
function AuthHandler:on_info(text)
    print(text)
end

--- Invoked when an error is encountered during authentication.
--- Fatal errors indicate the end of authentication.
---
--- @param err {kind:'fatal'|'error', text:string}
function AuthHandler:on_error(err)
    log.fmt_error('Authentication error: %s', err.text)

    if not self.finished then
        self.finished = err.kind == 'fatal'
    end
end

--- Invoked when authentication is finishd
function AuthHandler:on_finished()
    log.trace('Authentication finished')
    self.finished = true
end

--- Invoked whenever an unknown authentication msg is received.
--- @param x any
function AuthHandler:on_unknown(x)
    log.fmt_error('Unknown authentication event received: %s', x)
end

return AuthHandler
