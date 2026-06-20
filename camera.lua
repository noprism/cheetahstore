local component = require("component")
local term = require("term")

-- Prüfen, ob Kamera und GPU vorhanden sind
if not component.isAvailable("camera") then
  print("Keine Computronics Kamera gefunden! Bitte anschließen.")
  return
end

local camera = component.camera
local gpu = component.gpu

-- Bildschirm-Auflösung einstellen (Je höher, desto mehr laggt es potenziell)
local resX, resY = 80, 25
gpu.setResolution(resX, resY)

-- Eine Palette von ASCII-Zeichen, geordnet nach "Helligkeit" bzw. Nähe
-- Nahe Blöcke sind "#", weit entfernte sind "." und nichts (-1) ist ein Leerzeichen.
local chars = {"#", "@", "%", "O", "o", "*", "+", "-", ".", " "}
local maxDistance = 32 -- Die maximale Reichweite der Computronics Kamera

term.clear()
print("Starte Kamera-Scanner... (Abbruch mit Strg+C)")
os.sleep(1)

while true do
  for y = 1, resY do
    local line = ""
    for x = 1, resX do
      -- Bildschirmkoordinaten in Winkel von -1.0 bis 1.0 umrechnen
      local angleX = (x / resX) * 2 - 1
      local angleY = (y / resY) * 2 - 1
      
      -- Distanz abfragen
      local dist = camera.distance(angleX, angleY)
      
      -- Wenn ein Block getroffen wurde (Wert größer als 0)
      if dist and dist > 0 then
        -- Distanz auf den Index unseres Arrays mappen
        local index = math.floor((dist / maxDistance) * #chars) + 1
        
        -- Sicherstellen, dass der Index nicht aus dem Rahmen fällt
        if index > #chars then index = #chars end
        if index < 1 then index = 1 end
        
        line = line .. chars[index]
      else
        -- -1 bedeutet: Nichts in Reichweite
        line = line .. " "
      end
    end
    -- Zeile direkt an der richtigen Position überschreiben (verhindert Bildschirm-Flackern)
    term.setCursor(1, y)
    term.write(line)
  end
  
  -- Eine kleine Pause, um den Minecraft-Server nicht zum Absturz zu bringen
  os.sleep(0.1)
end