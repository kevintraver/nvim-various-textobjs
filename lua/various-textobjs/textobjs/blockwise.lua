local M = {}
local u = require("various-textobjs.utils")
--------------------------------------------------------------------------------

---@param lineNr number
---@return boolean
local function isBlankLine(lineNr)
	local lastLine = vim.api.nvim_buf_line_count(0)
	if lineNr > lastLine or lineNr < 1 then return true end
	local lineContent = u.getline(lineNr)
	return lineContent:find("^%s*$") ~= nil
end

---@param startLnum integer
---@param endLnum integer
local function setLinewiseSelection(startLnum, endLnum)
	u.saveJumpToJumplist()
	vim.api.nvim_win_set_cursor(0, { startLnum, 0 })
	if vim.fn.mode() ~= "V" then u.normal("V") end
	u.normal("o")
	vim.api.nvim_win_set_cursor(0, { endLnum, 0 })
end

---Contiguous non-blank lines, optionally restricted by indentation
---@param scope "inner"|"outer" inner: same indent only, outer: all contiguous non-blank lines
function M.block(scope)
	local curLnum = vim.api.nvim_win_get_cursor(0)[1]
	local lastLine = vim.api.nvim_buf_line_count(0)

	-- Get indent level, handling blank lines specially
	-- (vim.fn.indent returns 0 for whitespace-only lines)
	local startIndent
	if isBlankLine(curLnum) then
		local whitespace = u.getline(curLnum):match("^[ \t]*") or ""
		if #whitespace == 0 then
			setLinewiseSelection(curLnum, curLnum)
			return
		end
		startIndent = vim.fn.strdisplaywidth(whitespace)
	else
		startIndent = vim.fn.indent(curLnum)
	end

	local function isBlockBoundary(lnum)
		if isBlankLine(lnum) then return true end
		if scope == "outer" then return false end
		return vim.fn.indent(lnum) ~= startIndent
	end

	local function findEdge(lnum, step)
		while true do
			local nextLnum = lnum + step
			if nextLnum < 1 or nextLnum > lastLine then break end
			if isBlockBoundary(nextLnum) then break end
			lnum = nextLnum
		end
		return lnum
	end

	setLinewiseSelection(findEdge(curLnum, -1), findEdge(curLnum, 1))
end

--------------------------------------------------------------------------------

---Column Textobj (blockwise up and/or down until indent or shorter line)
---@param direction string "down" (default), "up", "both"
function M.column(direction)
	if direction == "both" then
		M.column("up")
		u.normal("oO")
		M.column("down")
		return
	end

	local step, key = 1, "j"
	if direction == "up" then
		step, key = -1, "k"
	end

	local lastLnum = vim.api.nvim_buf_line_count(0)
	local startRow = vim.api.nvim_win_get_cursor(0)[1]
	local trueCursorCol = vim.fn.virtcol(".") -- virtcol accurately accounts for tabs as indentation
	local extraColumns = vim.v.count1 - 1 -- before running other :normal commands, since they change v:count

	local nextLnum = startRow

	repeat
		nextLnum = nextLnum + step
		if nextLnum > lastLnum or nextLnum < 0 then break end
		local trueLineLength = #u.getline(nextLnum):gsub("\t", string.rep(" ", vim.bo.tabstop))
		local shorterLine = trueLineLength <= trueCursorCol
		local hitsIndent = trueCursorCol <= vim.fn.indent(nextLnum)
	until hitsIndent or shorterLine
	local linesToMove = step * (nextLnum - startRow) - 1

	-- SET POSITION
	u.saveJumpToJumplist()

	-- start visual block mode ( requires special character `^V`)
	if not (vim.fn.mode() == "") then vim.cmd.execute([["normal! \<C-v>"]]) end

	-- not using `setCursor`, since its column-positions are messed up by tab indentation
	-- not using `G` to go down lines, since affected by `opt.startofline`
	if linesToMove > 0 then u.normal(tostring(linesToMove) .. key) end
	if extraColumns > 0 then u.normal(tostring(extraColumns) .. "l") end
end

--------------------------------------------------------------------------------
return M
