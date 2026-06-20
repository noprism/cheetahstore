local component = require("component")
local term = require("term")

if not component.isAvailable("camera") then
  print("Keine Computronics Kamera gefunden!")
  return
end

local camera = component.camera
local gpu = component.gpu

-- Prüfen, ob die Grafikkarte genügend Farben unterstützt
if gpu.maxDepth() < 4 then
  print("Achtung: Dein Bildschirm oder deine Grafikkarte unterstuetzt keine echten Farben.")
  print("Bitte nutze Tier 2 oder Tier 3 Komponenten fuer das grafische Skript.")
  os.sleep(3)
end

-- Auflösung einstellen (Je höher, desto detailreicher, aber auch VIEL langsamer)
-- 80x25 ist ein guter Mittelweg. 
local resX, resY = 80, 25
gpu.setResolution(resX, resY)

local maxDistance = 32

term.clear()
print("Starte grafischen Scanner... (Abbruch mit Strg+C)")
os.sleep(1)

while true do
  for y = 1, resY do
    for x = 1, resX do
      -- Bildschirmkoordinaten in Winkel umrechnen (-1.0 bis 1.0)
      local angleX = (x / resX) * 2 - 1
      local angleY = (y / resY) * 2 - 1
      
      -- Distanz abfragen
      local dist = camera.distance(angleX, angleY)
      local color = 0x000000 -- Standard: Schwarz (Nichts / Himmel)
      
      -- Wenn wir einen Block treffen, der in Reichweite ist
      if dist and dist > 0 and dist <= maxDistance then
        -- Intensität berechnen (Nah = 1.0, Fern = 0.0)
        local intensity = 1 - (dist / maxDistance)
        if intensity < 0 then intensity = 0 end
        
        -- Graustufenwert berechnen (0 bis 255)
        local gray = math.floor(intensity * 255)
        
        -- In eine OpenComputers RGB-Hex-Farbe umrechnen: (R * 65536) + (G * 256) + B
        color = (gray * 65536) + (gray * 256) + gray
      end
      
      -- Dem "Pixel" die berechnete Farbe geben
      gpu.setBackground(color)
      -- Ein Leerzeichen an der Koordinate "malt" das farbige Pixel
      gpu.set(x, y, " ") 
    end
  end
  
  -- Hintergrund wieder auf Schwarz setzen, bevor das Bild neu lädt
  gpu.setBackground(0x000000)
  os.sleep(0.05)
end
