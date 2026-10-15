local t = require('tests/helper')
local variant = require('src/variant')

t.check('release folder', not variant.isDev('C:/AC/apps/lua/Flags'))
t.check('dev folder', variant.isDev('C:/AC/apps/lua/Flags_dev'))
t.check('dev folder with trailing separator', variant.isDev('C:\\AC\\apps\\lua\\Flags_dev\\'))
t.check('suffix only counts at the end', not variant.isDev('C:/code_dev/apps/lua/Flags'))
t.check('release title unchanged', variant.title('Flags', false) == 'Flags')
t.check('dev title suffixed', variant.title('Flags', true) == 'Flags (dev)')

t.finish()
