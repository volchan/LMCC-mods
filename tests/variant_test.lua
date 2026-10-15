local t = require('tests/helper')
local variant = require('src/variant')

t.check('release folder', not variant.isDev('C:/AC/apps/lua/LMCC_Flags'))
t.check('dev folder', variant.isDev('C:/AC/apps/lua/LMCC_Flags_dev'))
t.check('dev folder with trailing separator', variant.isDev('C:\\AC\\apps\\lua\\LMCC_Flags_dev\\'))
t.check('suffix only counts at the end', not variant.isDev('C:/code_dev/apps/lua/LMCC_Flags'))
t.check('release title unchanged', variant.title('LMCC Flags', false) == 'LMCC Flags')
t.check('dev title suffixed', variant.title('LMCC Flags', true) == 'LMCC Flags (dev)')

t.finish()
