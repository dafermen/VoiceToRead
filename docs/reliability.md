# Reliability validation
All physical measurements are pending. Use Release on a compatible iPhone with installed en-US assets, Airplane Mode and Wi-Fi off. Use the same reproducible conference audio, distance and caption settings.
| Run | Duration | Memory start/peak/end | CPU | Battery delta | Thermal | Live latency | Result |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Short | 30 min | Pending | Pending | Pending | Pending | Pending | Not run |
| Conference | 60 min | Pending | Pending | Pending | Pending | Pending | Not run |
| Extended | 120 min | Pending | Pending | Pending | Pending | Pending | Not run |
Use Instruments Allocations/Leaks/Time Profiler and Energy Log where available. Record device/OS/SDK/build, ambient conditions, transcript count, queue overflow/errors, frame continuity and UI scroll responsiveness.
Exercise call, Siri, accessory connect/disconnect, low storage, low battery, lock, foreground/background and missing/deleted assets. Verify safe stopped states and saved final captions after relaunch.
Raw audio queues are bounded at 64 buffers, converted inputs at 128 and result events at 256. Overflow stops analysis; it is not silent data loss.
Partial segments are provisional and may be discarded when background/interruption cancels a run; the UI explains this.
Render 300 recent final rows initially, with explicit older-caption loading; retain all finalized segments for storage/export. Avoid a single growing Text.
Persistence upserts finalized segments individually. Duration/capacity checkpoint every 30 seconds while listening. Saving still occurs on MainActor; profile its cost before release and move persistence to a ModelActor if measurements require it.
Do not claim two-hour support until these checks pass.
