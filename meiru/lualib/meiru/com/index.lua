

local names = {
	"com", 
	"combody", 
	"comcookie", 
	"comcsrf",
	"comcors",
	"comfinish",

	"comhandle",
	"comheader",
	"cominit",
	"compath",
	"comrender",

	"comresponse",
	"comsession",
	"comstatic"
}
local models = {}
for _,name in ipairs(names) do
	local model = include(name, ...)
	models[model.__cname] = model
end
return models
