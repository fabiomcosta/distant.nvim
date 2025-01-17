local fn = require('distant.fn')
local Driver = require('spec.e2e.driver')

describe('fn', function()
    local driver

    before_each(function()
        driver = Driver:setup({ label = 'fn.capabilities' })
    end)

    after_each(function()
        driver:teardown()
    end)

    describe('capabilities', function()
        it('should report back capabilities of the server', function()
            local err, res = fn.capabilities()
            assert(not err, err)

            -- TODO: Can we verify this any further? We'd need
            --       to make assumptions about the remote server
            assert.is.truthy(res)
            assert.is.truthy(res.supported)
        end)
    end)
end)
