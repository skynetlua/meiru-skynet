local system = require "api.system"
local meiru  = require "meiru.meiru"

local router = meiru.router()

router.get('/api/system/:what', system.index)

return router