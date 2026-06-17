local component = require("component")
local event = require("event")
local internet = require("internet")
local computer = require("computer")
local term = require("term")
local unicode = require("unicode")

-- Check if required components are available
if not component.isAvailable("tape_drive") or not component.isAvailable("internet") then
  print("Error: Tape drive or internet card is missing!")
  return
end

local tape = component.tape_drive
local gpu = component.gpu

-- State variables
local running = true
local loopEnabled = false
local clearMessageTime = 0
local currentLang = "de" -- Default language

-- Color palette (MineOS Style)
local C_BG = 0xE1E1E1
local C_TEXT = 0x3C3C3C
local C_TITLE = 0x2D2D2D
local C_WHITE = 0xFFFFFF
local C_GREEN = 0x009900
local C_RED = 0x990000
local C_BLUE = 0x0066CC
local C_BTN = 0x444444
local C_PROG_BG = 0xCCCCCC

-----------------------------------------
-- Localization / Dictionary
-----------------------------------------
local lang = {
  en = {
    title = "Tape Deck Manager Pro",
    btnUrl = " [ URL & Download ] ",
    btnName = " [ Rename Tape ] ",
    btnLang = " [ EN / DE ] ",
    btnPlay = " Play ",
    btnStop = " Stop ",
    loopOn = " Loop: ON ",
    loopOff = " Loop: OFF ",
    statusInserted = "Status: Tape INSERTED",
    statusNone = "Status: NO Tape",
    capacity = "Capacity: ",
    name = "Name: ",
    unnamed = "Unnamed",
    info = "Info: ",
    msgReady = "Ready.",
    msgErrTape = "Error: No tape inserted!",
    msgErrUrl = "Error: Invalid URL!",
    msgErrEmpty = "Error: Name cannot be empty!",
    msgErrBig = "Failsafe: File too big! Aborted.",
    msgConn = "Connecting to server...",
    msgStart = "Starting download...",
    msgWrite = "Writing: %d / %d Bytes",
    msgDone = "Download & write successful!",
    msgRenamed = "Tape successfully renamed!",
    msgEndLoop = "Tape ended. Starting loop...",
    msgEndRew = "Tape ended. Rewound.",
    inputUrl = " URL: ",
    inputName = " New Name: "
  },
  de = {
    title = "Tape Deck Manager Pro",
    btnUrl = " [ URL & Download ] ",
    btnName = " [ Umbenennen ] ",
    btnLang = " [ DE / EN ] ",
    btnPlay = " Play ",
    btnStop = " Stop ",
    loopOn = " Loop: AN ",
    loopOff = " Loop: AUS ",
    statusInserted = "Status: Kassette EINGELEGT",
    statusNone = "Status: KEINE Kassette",
    capacity = "Kapazität: ",
    name = "Name: ",
    unnamed = "Unbenannt",
    info = "Info: ",
    msgReady = "Bereit.",
    msgErrTape = "Fehler: Keine Kassette eingelegt!",
    msgErrUrl = "Fehler: URL ungültig!",
    msgErrEmpty = "Fehler: Name darf nicht leer sein!",
    msgErrBig = "Failsafe: Datei zu groß! Abbruch.",
    msgConn = "Verbinde mit Server...",
    msgStart = "Starte Download...",
    msgWrite = "Schreibe: %d / %d Bytes",
    msgDone = "Download & Schreiben erfolgreich!",
    msgRenamed = "Tape erfolgreich umbenannt!",
    msgEndLoop = "Tape-Ende erreicht. Starte Loop...",
    msgEndRew = "Tape-Ende erreicht. Zurückgespult.",
    inputUrl = " URL: ",
    inputName = " Neuer Name: "
  }
}

-- Helper function to fetch the correct translated string
local function t(key)
  return lang[currentLang][key] or key
end

local statusMsg = t("msgReady")

-----------------------------------------
-- Helper Functions
-----------------------------------------
-- Converts raw bytes to MM:SS format (6000 Bytes = 1 Second)
local function formatTime(bytes)
  local seconds = math.floor(bytes / 6000)
  local mins = math.floor(seconds / 60)
  local secs = seconds % 60
  return string.format("%02d:%02d", mins, secs)
end

-- Pads a string with spaces to prevent visual overlap during rendering
local function padRight(str, length)
  local len = unicode.len(str)
  if len < length then return str .. string.rep(" ", length - len) end
  return str
end

-- Sets a temporary status message that clears after 5 seconds
local function setMsg(msg)
  statusMsg = msg
  clearMessageTime = computer.uptime() + 5
end

-- Draws colored text at specific coordinates
local function drawText(x, y, text, fg, bg)
  gpu.setForeground(fg)
  gpu.setBackground(bg)
  gpu.set(x, y, text)
end

-- Draws a filled rectangle (used for backgrounds and progress bars)
local function drawRect(x, y, width, height, bg)
  gpu.setBackground(bg)
  gpu.fill(x, y, width, height, " ")
end

-----------------------------------------
-- UI Rendering (Static & Dynamic)
-----------------------------------------

-- Draws the static elements (background, title, buttons) only once
local function drawStaticUI()
  gpu.setResolution(60, 18)
  drawRect(1, 1, 60, 18, C_BG) 
  
  -- Title bar
  drawRect(1, 1, 60, 1, C_TITLE)
  drawText(2, 1, t("title"), C_WHITE, C_TITLE)

  -- Top row buttons
  drawText(2, 12, t("btnUrl"), C_WHITE, C_BTN)
  drawText(25, 12, t("btnName"), C_WHITE, C_BTN)
  drawText(46, 12, t("btnLang"), C_WHITE, C_BLUE) -- Language toggle

  -- Bottom row playback buttons
  drawText(3, 16, " |< ", C_WHITE, C_BTN)
  drawText(9, 16, " << ", C_WHITE, C_BTN)
  drawText(15, 16, t("btnPlay"), C_WHITE, C_GREEN)
  drawText(23, 16, t("btnStop"), C_WHITE, C_RED)
  drawText(31, 16, " >> ", C_WHITE, C_BTN)
  
  local loopStr = loopEnabled and t("loopOn") or t("loopOff")
  local loopColor = loopEnabled and C_BLUE or C_BTN
  drawText(37, 16, loopStr, C_WHITE, loopColor)
end

-- Updates the dynamic elements (time, tape status, progress bar) every tick
local function drawDynamicUI()
  local now = computer.uptime()
  
  -- Clear temporary messages
  if clearMessageTime > 0 and now >= clearMessageTime then
    statusMsg = t("msgReady")
    clearMessageTime = 0
  end

  if tape.isReady() then
    drawText(3, 3, padRight(t("statusInserted"), 40), C_GREEN, C_BG)
    
    local size = tape.getSize()
    local pos = tape.getPosition()
    
    drawText(3, 5, padRight(t("capacity") .. formatTime(size) .. " (" .. size .. " Bytes)", 50), C_TEXT, C_BG)
    local label = tape.getLabel()
    drawText(3, 4, padRight(t("name") .. (label and label ~= "" and label or t("unnamed")), 50), C_TEXT, C_BG)
    drawText(3, 6, padRight(formatTime(pos) .. " / " .. formatTime(size), 30), 0x555555, C_BG)
    
    -- Calculate and draw the dynamic progress bar
    drawRect(3, 8, 56, 1, C_PROG_BG) 
    local pct = size > 0 and (pos / size) or 0
    if pct > 1 then pct = 1 end
    local barWidth = math.floor(pct * 56)
    if barWidth > 0 then
      drawRect(3, 8, barWidth, 1, C_BLUE) 
    end
  else
    drawText(3, 3, padRight(t("statusNone"), 40), C_RED, C_BG)
    drawText(3, 4, padRight(t("name") .. "N/A", 50), C_TEXT, C_BG)
    drawText(3, 5, padRight(t("capacity") .. "N/A", 50), C_TEXT, C_BG)
    drawText(3, 6, padRight("00:00 / 00:00", 30), 0x555555, C_BG)
    drawRect(3, 8, 56, 1, C_PROG_BG) 
  end

  -- Draw the info/status line at the bottom
  drawText(3, 10, padRight(t("info") .. statusMsg, 55), C_BLUE, C_BG)
end

-----------------------------------------
-- Core Logic: Downloading
-----------------------------------------
local function startDownload(url)
  if not tape.isReady() then return setMsg(t("msgErrTape")) end
  tape.stop()
  tape.seek(-tape.getSize())
  
  setMsg(t("msgConn"))
  drawDynamicUI()

  local success, response = pcall(internet.request, url)
  if not success or not response then return setMsg(t("msgErrUrl")) end

  local maxCapacity = tape.getSize()
  local writtenBytes = 0
  setMsg(t("msgStart"))

  -- Process the download in chunks to avoid locking up the system
  for chunk in response do
    if writtenBytes + #chunk > maxCapacity then
      computer.beep(400, 1)
      return setMsg(t("msgErrBig"))
    end
    tape.write(chunk)
    writtenBytes = writtenBytes + #chunk
    
    -- Live update of the progress bar during download
    statusMsg = string.format(t("msgWrite"), writtenBytes, maxCapacity)
    local pct = writtenBytes / maxCapacity
    local barWidth = math.floor(pct * 56)
    drawRect(3, 8, 56, 1, C_PROG_BG)
    if barWidth > 0 then drawRect(3, 8, barWidth, 1, C_BLUE) end
    drawText(3, 10, padRight(t("info") .. statusMsg, 55), C_BLUE, C_BG)
  end

  computer.beep(1000, 0.5)
  setMsg(t("msgDone"))
end

-----------------------------------------
-- Main Event Loop
-----------------------------------------
term.clear()
drawStaticUI()

while running do
  drawDynamicUI()
  
  -- Wait max 1 second for touch events (Allows flicker-free ticking)
  local ev, _, x, y = event.pull(1)

  if ev == "touch" then
    
    -- Row 16: Playback controls & Loop
    if y == 16 then
      if x >= 3 and x <= 6 then if tape.isReady() then tape.seek(-tape.getPosition()) end
      elseif x >= 9 and x <= 12 then if tape.isReady() then tape.seek(-60000) end
      elseif x >= 15 and x <= 20 then if tape.isReady() then tape.play() end
      elseif x >= 23 and x <= 28 then if tape.isReady() then tape.stop() end
      elseif x >= 31 and x <= 34 then if tape.isReady() then tape.seek(60000) end
      elseif x >= 37 and x <= 47 then
        loopEnabled = not loopEnabled
        setMsg(loopEnabled and t("msgEndLoop") or t("msgEndRew")) -- Temporary message feedback
        drawStaticUI() -- Force redraw to update button color
      end
    
    -- Row 12: Action buttons & Language Switch
    elseif y == 12 then
      -- Button: Enter URL
      if x >= 2 and x <= 22 then
        drawRect(1, 18, 60, 1, 0x000000)
        drawText(1, 18, t("inputUrl"), C_WHITE, 0x000000)
        term.setCursor(unicode.len(t("inputUrl")) + 1, 18)
        local url = io.read()
        drawStaticUI() 
        if url and url ~= "" then startDownload(url) end
        
      -- Button: Rename Tape
      elseif x >= 25 and x <= 42 then
        if not tape.isReady() then
          setMsg(t("msgErrTape"))
        else
          drawRect(1, 18, 60, 1, 0x000000)
          drawText(1, 18, t("inputName"), C_WHITE, 0x000000)
          term.setCursor(unicode.len(t("inputName")) + 1, 18)
          local name = io.read()
          drawStaticUI()
          if name and name ~= "" then
            tape.setLabel(name)
            setMsg(t("msgRenamed"))
          end
        end
        
      -- Button: Language Toggle
      elseif x >= 46 and x <= 58 then
        currentLang = (currentLang == "de") and "en" or "de"
        statusMsg = t("msgReady")
        drawStaticUI()
      end
    end
  
  elseif ev == "interrupted" then
    running = false
  end

  -- Background Tick Logic: Auto-Rewind / Loop handler
  if tape.isReady() then
    local size = tape.getSize()
    local pos = tape.getPosition()
    if size > 0 and pos >= size then
      tape.stop()
      tape.seek(-pos)
      if loopEnabled then
        tape.play()
        setMsg(t("msgEndLoop"))
      else
        setMsg(t("msgEndRew"))
      end
    end
  end
end

-- Cleanup on exit
gpu.setBackground(0x000000)
gpu.setForeground(0xFFFFFF)
term.clear()
print("Tape Deck Manager terminated.")