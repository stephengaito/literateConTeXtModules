-- A Lua file

-- from file: preamble.tex starting line: 63

-- This is the lua code associated with t-literate-progs.mkiv

if not modules then modules = { } end
modules ['t-literate-progs'] = {
    version   = 1.000,
    comment   = "Literate Programming in ConTeXt - lua",
    author    = "PerceptiSys Ltd (Stephen Gaito)",
    copyright = "PerceptiSys Ltd (Stephen Gaito)",
    license   = "MIT License"
}

thirddata               = thirddata               or {}
thirddata.literateProgs = thirddata.literateProgs or {}

local litProgs  = thirddata.literateProgs
litProgs.code   = {}
local code      = litProgs.code
code.mkiv       = {}
code.lua        = {}
code.templates  = {}
code.lakefile   = {}

local pp = require('pl/pretty')
local tInsert = table.insert
local tRemove = table.remove
local tConcat = table.concat
local tSort   = table.sort
local sFmt    = string.format
local sMatch  = string.match
local toStr   = tostring

-- from file: rendering.tex starting line: 80

local function compareKeyValues(a, b)
  return (a[1] < b[1])
end

local function prettyPrint(anObj, indent)
  local result = ""
  indent = indent or ""
  if type(anObj) == 'nil' then
    result = 'nil'
  elseif type(anObj) == 'boolean' then
    if anObj then result = 'true' else result = 'false' end
  elseif type(anObj) == 'number' then
    result = toStr(anObj)
  elseif type(anObj) == 'string' then
    result = '"'..anObj..'"'
  elseif type(anObj) == 'function' then
    result = toStr(anObj)
  elseif type(anObj) == 'userdata' then
    result = toStr(anObj)
  elseif type(anObj) == 'thread' then
    result = toStr(anObj)
  elseif type(anObj) == 'table' then
    local origIndent = indent
    indent = indent..'  '
    result = '{\n'
    for i, aValue in ipairs(anObj) do
      result = result..indent..prettyPrint(aValue, indent)..',\n'
    end
    local theKeyValues = { }
    for aKey, aValue in pairs(anObj) do
      if type(aKey) ~= 'number' or aKey < 1 or #anObj < aKey then
        tInsert(theKeyValues,
          { prettyPrint(aKey), aKey, prettyPrint(aValue, indent) })
      end
    end
    tSort(theKeyValues, compareKeyValues)
    for i, aKeyValue in ipairs(theKeyValues) do
      result = result..indent..'['..aKeyValue[1]..'] = '..aKeyValue[3]..',\n'
    end
    result = result..origIndent..'}'
  else
    result = 'UNKNOWN TYPE: ['..toStr(anObj)..']'
  end
  return result
end

litProgs.prettyPrint = prettyPrint

-- from file: rendering.tex starting line: 154

local function reportTemplateError(aTemplateStr, errMessage)
  texio.write_nl('---------------------------')
  texio.write_nl(errMessage)
  texio.write_nl("Template:")
  texio.write_nl(aTemplateStr)
  texio.write_nl("Ignoring this attribute action")
  texio.write_nl('---------------------------')
end

local function parseTemplate(aTemplateStr)
  local theTemplate = { }

  if type(aTemplateStr) == 'string' then
    -- we only do anything if we have been given
    -- an explicit string
    local position = 1
    while aTemplateStr:find('{{', position, true) do

      local endText, startChunk = aTemplateStr:find('{{', position, true)
      if position < endText then
        local textChunk = aTemplateStr:sub(position, endText-1)
        if textChunk and 0 < #textChunk then
          tInsert(theTemplate, textChunk)
        end
      end
      position = startChunk + 1

      local endChunk, startText = aTemplateStr:find('}}', position, true)
      if position < endChunk then
        local luaChunk = aTemplateStr:sub(position, endChunk-1)
        if luaChunk and 0 < #luaChunk then
          local actionType = luaChunk:sub(1,1)
          local luaChunk = luaChunk:sub(2)
          local arguments = { }
          for anArg in luaChunk:gmatch('[^,]+') do
            tInsert(arguments, anArg:match("^%s*(.-)%s*$"))
          end
          if actionType == '=' then
            if 0 < #arguments then
              tInsert(theTemplate, { 'reference', arguments[1] })
            else
              reportTemplateError(aTemplateStr,
                "No attribute specified"
              )
            end
          elseif actionType == '!' then
            if 0 < #arguments then
              tInsert(theTemplate, { 'application', arguments })
            else
              reportTemplateError(aTemplateStr,
                "No template specified"
              )
            end
          elseif actionType == '|' then
            if 2 < #arguments then
              tInsert(theTemplate, { 'mapping', arguments })
            else
              reportTemplateError(aTemplateStr,
                "No attribute, separator or template specified"
              )
            end
          else
            reportTemplateError(aTemplateStr,
              sFmt("Unknown template attribute action [%s]",
                actionType)
            )
          end
        end
      end
      position = startText + 1
    end

    if position <= #aTemplateStr then
      tInsert(theTemplate, aTemplateStr:sub(position))
    end
  end
  return theTemplate
end

litProgs.parseTemplate = parseTemplate

-- from file: rendering.tex starting line: 322

local function getReference(aReference, anEnv)
  if type(aReference) ~= 'string' then return nil end
  local redirect = aReference:sub(1,1)
  if redirect == '*' then
    local newRef = aReference:sub(2)
    local indirectRef = getReference(newRef, anEnv)
    if indirectRef and type(indirectRef) == 'string' then
      return getReference(indirectRef, anEnv)
    else
      return nil
    end
  end

  return anEnv[aReference]
end

litProgs.getReference = getReference

-- from file: rendering.tex starting line: 366

local function parseTemplatePath(templatePathStr, anEnv)
  if type(templatePathStr) ~= 'string' then
    texio.write_nl(
      sFmt("Expected [%s] to be a string.", tempaltePathStr)
    )
    texio.write_nl("Ignoring template.")
    return nil
  end
  if templatePathStr:sub(1,1) == '*' then
    templatePathStr = getReference(templatePathStr:sub(2), anEnv)
  end
  local templatePath = { }
  for subTemplate in templatePathStr:gmatch('[^%.]+') do
    tInsert(templatePath, subTemplate)
  end
  return templatePath
end

litProgs.parseTemplatePath = parseTemplatePath

-- from file: rendering.tex starting line: 424

local function navigateToTemplate(templatePath)
  litProgs.templates = litProgs.templates or { }
  local curTable = litProgs.templates
  for i, templateDir in ipairs(templatePath) do
    curTable[templateDir] = curTable[templateDir] or { }
    curTable = curTable[templateDir]
  end
  return curTable
end

litProgs.navigateToTemplate = navigateToTemplate

-- from file: rendering.tex starting line: 486

local function addTemplate(templatePathStr, templateArgs, templateStr)
  local templatePath = parseTemplatePath(templatePathStr)
  if not templatePath then return nil end
  local templateTable    = navigateToTemplate(templatePath)
  templateTable.path     = templatePathStr
  templateTable.args     = templateArgs
  templateTable.template = parseTemplate(templateStr)
end

litProgs.addTemplate = addTemplate

-- from file: rendering.tex starting line: 543

local function buildNewEnv(template, arguments, anEnv)
  if type(template)      ~= 'table' or
     type(template.args) ~= 'table' or
     type(arguments)     ~= 'table' or
     type(anEnv)         ~= 'table' then
    return { }
  end
  local formalArgs = template.args
  local newEnv = { }
  for i, aFormalArg in ipairs(formalArgs) do
    newEnv[aFormalArg] = getReference(arguments[i], anEnv)
  end
  return newEnv
end

litProgs.buildNewEnv = buildNewEnv

-- from file: rendering.tex starting line: 616

local function renderer(aTemplate, anEnv)
  if type(aTemplate) == 'table' and
     type(aTemplate.template) == 'table' then
    local result = { }
    for i, aChunk in ipairs(aTemplate.template) do
      if type(aChunk) == 'string' then
        -- a simple litteral string... add it
        tInsert(result, aChunk)
      elseif type(aChunk) == 'table' and 2 <= #aChunk then
        local actionType = aChunk[1]
        local arguments  = aChunk[2]
        if actionType == 'reference' then
          if type(arguments) == 'string' then
            local attrValue = getReference(arguments, anEnv)
            tInsert(result, toStr(attrValue))
          end
        elseif actionType == 'application' then
          if type(arguments) == 'table' and 1 < #arguments then
            local templatePath = tRemove(arguments, 1)
            if type(templatePath) == 'string' then
              templatePath   = parseTemplatePath(templatePath, anEnv)
              local template = navigateToTemplate(templatePath)
              local newEnv   = buildNewEnv(template, arguments, anEnv)
              local templateValue = renderer(template, newEnv)
              if type(templateValue) == 'string' then
                tInsert(result, templateValue)
              end
            end
          end
        elseif actionType == 'mapping' then
          if type(arguments) == 'table' and 4 <= #arguments then
            local attrList     = tRemove(arguments, 1)
            local separator    = tRemove(arguments, 1)
            local templatePath = tRemove(arguments, 1)
            local listArg      = tRemove(arguments, 1)
            if type(attrList)     == 'string' and
               type(separator)    == 'string' and
               type(templatePath) == 'string' and
               type(listArg)      == 'string' then
              attrList       = getReference(attrList,  anEnv)
              separator      = getReference(separator, anEnv)
              templatePath   = parseTemplatePath(templatePath, anEnv)
              local template = navigateToTemplate(templatePath)
              local newEnv   = buildNewEnv(template, arguments, anEnv )
              if type(separator) ~= 'string' then
                separator = ''
              end
              if type(attrList) ~= 'table' then
                attrList = { attrList }
              end
              if type(attrList) == 'table' and 0 < #attrList then
                for i, anAttrValue in ipairs(attrList) do
                  newEnv[listArg] = anAttrValue
                  local templateValue = renderer(template, newEnv)
                  if type(templateValue) == 'string' then
                    tInsert(result, templateValue)
                  end
                  if i < #attrList then
                    tInsert(result, separator)
                  end
                end
              end
            end
          end
        end
      end
    end
    return tConcat(result)
  else
    return ""
  end
end

litProgs.renderer = renderer

-- from file: rendering.tex starting line: 734

local function renderCodeFile(aFilePath, codeTable)
  local outFile = io.open(aFilePath, 'w')
  outFile:write(tConcat(codeTable, '\n\n'))
  outFile:close()
end

-- from file: codeManipulation.tex starting line: 281

function litProgs.setCodeStream(aCodeStream)
  code.curCodeStream = aCodeStream
end

function litProgs.addCode(aCodeType, bufferName)
  local bufferContents  =
    buffers.getcontent(bufferName):gsub("\13", "\n")
  code[aCodeType]       = code[aCodeType] or { }
  local codeType        = code[aCodeType]
  local aCodeStream     = code.curCodeStream or 'default'
  codeType[aCodeStream] = codeType[aCodeStream] or { }
  local codeStream      = codeType[aCodeStream]
  tInsert(codeStream, bufferContents)
end

function litProgs.createCodeFile(aCodeType,
                                 aCodeStream,
                                 aFilePath)
  -- here be dragons! -- how do we pass in cType and cSubType
  renderFile(aFilePath, litProgs.templates.lua.file)
  -- here be dragons!
end

-- from file: mkivCode.tex starting line: 109

function litProgs.markMkIVCodeOrigin()
  tInsert(code.mkiv,
    sFmt('%% from file: %s starting line: %s',
      status.filename,
      toStr(status.linenumber)
    )
  )
end

function litProgs.addMkIVCode(bufferName)
  local bufferContents = buffers.getcontent(bufferName):gsub("\13", "\n")
  tInsert(code.mkiv, bufferContents)
end

-- from file: mkivCode.tex starting line: 140

function litProgs.createMkIVFile(aFilePath)
  tInsert(code.mkiv, 1, '% A ConTeXt MkIV module')
  renderCodeFile(aFilePath, code.mkiv)
end

-- from file: luaCode.tex starting line: 25

function litProgs.markLuaCodeOrigin()
  tInsert(code.lua,
    sFmt('-- from file: %s starting line: %s',
      status.filename,
      toStr(status.linenumber)
    )
  )
end

function litProgs.addLuaCode(bufferName)
  local bufferContents = buffers.getcontent(bufferName):gsub("\13", "\n")
  tInsert(code.lua, bufferContents)
end

function litProgs.createLuaFile(aFilePath)
  tInsert(code.lua, 1, '-- A Lua file')
  renderCodeFile(aFilePath, code.lua)
end

-- from file: luaTemplates.tex starting line: 25

function litProgs.markLuaTemplateOrigin()
  tInsert(code.templates,
    sFmt('-- from file: %s starting line: %s',
      status.filename,
      toStr(status.linenumber)
    )
  )
end

function litProgs.addLuaTemplate(bufferName)
  local bufferContents = buffers.getcontent(bufferName):gsub("\13", "\n")
  tInsert(code.templates, bufferContents)
end

function litProgs.createLuaTemplateFile(aFilePath)
  tInsert(code.templates, 1, '-- A Lua template file')
  renderCodeFile(aFilePath, code.templates)
end

-- from file: lakefiles.tex starting line: 23

function litProgs.addLakefile(bufferName)
  local bufferContents = buffers.getcontent(bufferName):gsub("\13", "\n")
  tInsert(code.lakefile, bufferContents)
end

function litProgs.createLakefile(aFilePath)
  renderCodeFile(aFilePath, code.lakefile)
end