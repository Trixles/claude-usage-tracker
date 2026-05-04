#!/usr/bin/env python3
"""Touch the CUT refresh trigger file to force an immediate backend poll."""
from pathlib import Path
trigger = Path.home() / ".local" / "share" / "cut" / "refresh.trigger"
trigger.parent.mkdir(parents=True, exist_ok=True)
trigger.touch()
