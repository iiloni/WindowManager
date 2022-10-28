#IfWinNotActive ahk_exe Wow.exe
!c:: MoveWindowAndResize()
!+c:: MoveWindowAndResize(,0.3, 0.9, true, true)
;!t:: MonitorTest() Debugging function
;!t:: ProcessTest() Debugging Function

ProcessTest(WinTitle:="A") {
	WinGetTitle, title, %WinTitle%
	testArr := ["- Files"]
	ret := ContainsInArray(title, testArr)
	MsgBox, %title% `n%ret%

}

; Display monitor information
MonitorTest() { 
	monitor := GetTargetMonitor()
	SysGet, monCoords, Monitor, %monitor%
	height := monCoordsBottom - monCoordsTop
	width := monCoordsRight - monCoordsLeft
	MsgBox, Monitor:%monitor% `nLeft: %monCoordsLeft% -- Top: %monCoordsTop% -- Right: %monCoordsRight% -- Bottom %monCoordsBottom% `nHeight: %height% -- Width: %width%.
}

MoveWindowAndResize(WinTitle:="A", ResizeWidthScale:=0.7, ResizeHeightScale:=0.9, Override:=false, SideSnap:=false) {
	WinGet, maxed, MinMax, %WinTitle%
	if (maxed = 1) { ; if window is maximized, unmaximize before applying effects
		WinRestore, %WinTitle%
	} else if (maxed = -1) { ; if window is minimized, don't do anything
		return
	}
	
	; Default window scaling factors
	; ResizeWidthScale := 0.7 ; 70% of horizontal monitor work area
	; ResizeHeightScale := 0.9 ; 90% of vertical monitor work area
	
	targetMonitor := GetTargetMonitor(WinTitle)
	CalculateMargins(targetMonitor)

	WinGet, activeProcess , ProcessName, %WinTitle%
	WinGetTitle, activeTitle, %WinTitle%
	FileBrowser := ["explorer.exe", "Explorer.EXE", "WindowsTerminal.exe"] ; 60% W 65% H, not overridable
	FileBrowserUWP := ["- Files"]
	SplitView := ["ApplicationFrameHost.exe"] ; 50% W 85% H, overridable
	SplitViewUWP := ["Microsoft To Do"] 

	; App specific behavior
	if (InArray(FileBrowser, activeProcess) OR ContainsInArray(activeTitle, FileBrowserUWP)) {
		ResizeWidthScale := .6
		ResizeHeightScale := .65
		
		unbounded := OutOfBounds(WinTitle)
		if (unbounded[0] != 0 OR unbounded[1] != 0) { ; window out of bounds
			BoundarySnap(WinTitle, targetMonitor, unbounded[0], unbounded[1])
		}
		Resize(WinTitle, ResizeWidthScale, ResizeHeightScale, targetMonitor)
	} else if ((InArray(SplitView, activeProcess) OR ContainsInArray(activeTitle, SplitViewUWP)) AND !Override) {
		ResizeWidthScale := .5
		ResizeHeightScale := .85

		unbounded := OutOfBounds(WinTitle)
		if (unbounded[0] != 0 OR unbounded[1] != 0) { ; window out of bounds
			BoundarySnap(WinTitle, targetMonitor, unbounded[0], unbounded[1])
		}
		Resize(WinTitle, ResizeWidthScale, ResizeHeightScale, targetMonitor)
	; Default behavior -- resize window, then either snap it in bounds or center it
    } else {
		unbounded := OutOfBounds(WinTitle)
		Resize(WinTitle, ResizeWidthScale, ResizeHeightScale, targetMonitor)
		if (unbounded[0] != 0 OR unbounded[1] != 0) { ; window out of bounds
			BoundarySnap(WinTitle, targetMonitor, unbounded[0], unbounded[1])
		} else { ; window in bounds
			Reposition(WinTitle, targetMonitor, SideSnap)	
		}
	}
}

; ----- Utility functions -----

/*
Determines if a given value is in a given array.
*/
InArray(Arr, Val) {
	inArr := false
	loop, % Arr.Length() {
		if (Arr[A_Index] = Val) {
			inArr := true
			break
		}
	}
	return inArr
}

/*
Determines if the given string contains any of the substrings in the array
*/
ContainsInArray(Val, Arr) {
	inArr := false
	loop, % Arr.Length() {
		if (inStr(Val, Arr[A_Index]) > 0) {
			inArr := true
			break
		}
	}
	return inArr
}

/*
Determines the target monitor - the screen that the window will be bounded to and manipulated on.
Uses coordinate plane to calculate the area of the window that is on each monitor in the system.
The monitor that has the largest area of the window on it is chosen as the target.
*/
GetTargetMonitor(WinTitle:="A") {
	Sysget, monCount, MonitorCount
	Sysget, primary, MonitorPrimary
	WinGetPos, actX, actY, actWidth, actHeight, %WinTitle%

	if (monCount = 1) {
		return 1
	}

	actCorners := []
	; Top left
	actCorners[0, 0] := actX
	actCorners[0, 1] := actY
	; Top right
	actCorners[1, 0] := actX + actWidth
	actCorners[1, 1] := actY
	; Bottom left
	actCorners[2, 0] := actX
	actCorners[2, 1] := actY + actHeight
	; Bottom right
	actCorners[3, 0] := actX + actWidth
	actCorners[3, 1] := actY + actHeight

	; Choose the monitor on which most of the active window's area is on.
	targetMon := 1
	targetActiveArea := 0
	currMon := 1
	currActiveArea := 0
	loop, %monCount% {
		Sysget, currMonCoords, Monitor, %currMon%
		/*
		[DEPRECATED]: AHK performs resolution normalization natively

		Determine resolution normalization factor by finding the scale difference between 1080 and the current monitor.
		This is necessary to allow the comparison of displays with different resolutions. 
		A 4k display has 4x the amount of pixels as a 1080p display in a window occupying the same ratio of screen space.
		*/
		;horizResNormFactor := 1920 / Abs(monCoordsRight - monCoordsLeft)
		;vertResNormFactor := 1080 / Abs(monCoordsBottom - monCoordsTop) 
		
		; top left on current monitor
		if ((currMonCoordsLeft < actCorners[0][0] AND actCorners[0][0] < currMonCoordsRight) AND (currMonCoordsTop < actCorners[0][1] AND actCorners[0][1] < currMonCoordsBottom)) {
			; For each X and Y axis, take the min of (this corner to adj corner) and (this corner to monitor boundary)
			currActiveArea := Min(Abs(actCorners[1][0] - actCorners[0][0]), Abs(currMonCoordsRight - actCorners[0][0])) * Min(Abs(actCorners[2][1] - actCorners[0][1]), Abs(currMonCoordsBottom - actCorners[0][1]))
		}
		; top right on current monitor
		if ((currMonCoordsLeft < actCorners[1][0] AND actCorners[1][0] < currMonCoordsRight) AND (currMonCoordsTop < actCorners[1][1] AND actCorners[1][1] < currMonCoordsBottom)) {
			currActiveArea := Min(Abs(actCorners[1][0] - actCorners[0][0]), Abs(actCorners[1][0] - currMonCoordsLeft)) * Min(Abs(actCorners[3][1] - actCorners[1][1]), Abs(currMonCoordsBottom - actCorners[1][1]))
		}
		; bottom left on current monitor
		if ((currMonCoordsLeft < actCorners[2][0] AND actCorners[2][0] < currMonCoordsRight) AND (currMonCoordsTop < actCorners[2][1] AND actCorners[2][1] < currMonCoordsBottom)) {
			currActiveArea := Min(Abs(actCorners[3][0] - actCorners[2][0]), Abs(currMonCoordsRight - actCorners[2][0])) * Min(Abs(actCorners[2][1] - actCorners[0][1]), Abs(actCorners[2][1] - currMonCoordsTop))
		}
		; bottom right on current monitor
		if ((currMonCoordsLeft < actCorners[3][0] AND actCorners[3][0] < currMonCoordsRight) AND (currMonCoordsTop < actCorners[3][1] AND actCorners[3][1] < currMonCoordsBottom)) {
			currActiveArea := Min(Abs(actCorners[3][0] - actCorners[2][0]), Abs(actCorners[3][0] - currMonCoordsLeft)) * Min(Abs(actCorners[3][1] - actCorners[1][1]), Abs(actCorners[3][1] - currMonCoordsTop))
		}
		
		; currActiveArea *= horizResNormFactor * vertResNormFactor ; scale the area to a baseline of 1920 x 1080.

		; compare active area
		if (currActiveArea > targetActiveArea) {
			targetActiveArea := currActiveArea
			targetMon := currMon
		}
		;MsgBox, % "Target: " . targetMon . " Current: " . currMon
		currMon++
	}
	return targetMon
}

/*
Calculates the coordinate X, Y values for the margins as determined by the scales.
The margins are made global for use in other functions.
*/
CalculateMargins(monitor) {
	Sysget, monCoords, MonitorWorkArea, %monitor%

	horizontalMarginScale := .1 ; Set margins as 10% of horizontal screen work space, 5% on each side
	verticalMarginScale := .05 ; Set margins as 5% of vertical screen work space, 2.5% on each side
	; Current functionality will vertically center all windows during snapping

	; Establish margin values
	global marginsCalculated := true
	global monWidth := Abs(monCoordsRight - monCoordsLeft)
	global monHeight := Abs(monCoordsBottom - monCoordsTop)
	global marginLeft := monCoordsLeft + (horizontalMarginScale / 2) * monWidth ; use complement of scale to determine margin
	global marginRight := monCoordsRight - (horizontalMarginScale / 2) * monWidth
	global marginTop := monCoordsTop + (verticalMarginScale / 2) * monHeight
	global marginBottom := monCoordsBottom - (verticalMarginScale / 2) * monHeight

	; Debugging message
	; MsgBox, Monitor:%monitor% `nLeft: %marginLeft% -- Top: %marginTop% -- Right: %marginRight% -- Bottom %marginBottom% `nHeight: %monHeight% -- Width: %monWidth%.
}

/*
Determines if the window is out of bounds for the specific display. Requires that margins have been calculated.
Uses the calculated margins to determine which axes need to be snapped back to the boundary, if any.
Returns a 2-item (horizontal, vertical) array denoting which screen borders have been crossed:

0 = no boundaries violated
1 = left / top boundary violated
2 = right / bottom boundary violated
*/
OutOfBounds(WinTitle) {
	WinGetPos, actX, actY, actWidth, actHeight, %WinTitle%

	global marginsCalculated
	if (!marginsCalculated) {
		MsgBox, "Error: margins not calculated! Call CalcualateMargins() first!"
	}

	; Establish margin values in current scope
	global monWidth 
	global monHeight 
	global marginLeft
	global marginRight 
	global marginTop 
	global marginBottom

	; Initialize bounding array
	unbounded := []
	unbounded[0] := 0
	unbounded[1] := 0

	; Horizontal bounding
	if (actX + actWidth > marginRight) {
		unbounded[0] := 2
	} else if (actX < marginLeft) {
		unbounded[0] := 1
	}

	; Vertical bounding
	if (actY + actHeight > marginBottom) {
		unbounded[1] := 2 
	} else if (actY < marginTop) {
		unbounded[1] := 1
	}
	
	; Debugging message
	; MsgBox, % "Horizontal: " . unbounded[0] . " -- Vertical: " . unbounded[1]

	return unbounded
}

; ----- Main functions -----

/*
Snaps a window back to the margins if it is unbounded on that axis.
*/
BoundarySnap(WinTitle, monitor, Horizontal, Vertical) {
	WinGetPos, actX, actY, actWidth, actHeight, %WinTitle%
	Sysget, monCoords, MonitorWorkArea, %monitor%

	; Establish margin values in current scope
	global monWidth 
	global monHeight 
	global marginLeft
	global marginRight 
	global marginTop 
	global marginBottom

	; initialize target coordinates to current position
	targetX := actX
	targetY := actY

	; Horizontal snapping
	if (Horizontal = 1) { ; left
		targetX := marginLeft 
	} else if (Horizontal = 2) { ; right
		targetX := marginRight - actWidth
	}

	; Vertical snapping
	if (Vertical = 1) { ; top
		targetY := marginTop
	} else if (Vertical = 2) { ; bottom
		targetY := marginBottom - actHeight
	}
	WinMove, %WinTitle%,, targetX, targetY
}

/*
Moves window to a prescribed position.
*/
Reposition(WinTitle, monitor, SideSnap) {
	WinGetPos, actX, actY, actWidth, actHeight, %WinTitle%
	Sysget, monCoords, MonitorWorkArea, %monitor%

	if (SideSnap) { ; Snap the window to the closest side
		global marginsCalculated
		if (!marginsCalculated) {
			MsgBox, "Error: margins not calculated! Call CalcualateMargins() first!"
		}

		; Determine which side the window is mostly on
		leftWidth := ((monCoordsRight + monCoordsLeft) / 2) - actX
		rightWidth :=  (actX + actWidth) - ((monCoordsRight + monCoordsLeft) / 2)
		if (leftWidth > rightWidth) {
			global marginLeft
			WinMove, %WinTitle%,, marginLeft, ((monCoordsBottom+monCoordsTop)/2) - (actHeight/2)
		} else {
			global marginRight
			WinMove, %WinTitle%,, marginRight - actWidth, ((monCoordsBottom+monCoordsTop)/2) - (actHeight/2)
		}
	} else { ; Center the window on the display
		WinMove, %WinTitle%,, ((monCoordsRight+monCoordsLeft)/2) - (actWidth/2), ((monCoordsBottom+monCoordsTop)/2) - (actHeight/2)
	}

	
}

/*
Resizes the window based on the designated height and width scales.
*/
Resize(WinTitle, WidthScale, HeightScale, monitor) {
	WinGetPos, actX, actY, actWidth, actHeight, %WinTitle%
	SysGet, monCoords, Monitor, %monitor%

	; Establish monitor width and height in local scope
	global monWidth 
	global monHeight 

	/*
	Use resolution normalization factors as a way to compensate for aspect ratios that deviate from 16:9. 
	Landscape monitors will have width compensation, portrait monitors will have height compensation.
	*/
	horizResNormFactor := 1920 / Abs(monCoordsRight - monCoordsLeft)
	vertResNormFactor := 1080 / Abs(monCoordsBottom - monCoordsTop) 
	
	if (monWidth > monHeight) { ; monitor is landscape
		baseResNormFactor := vertResNormFactor
	} else { ; monitor is portrait or square
		baseResNormFactor := horizResNormFactor
	}

	targetWidth := monWidth * WidthScale
	targetHeight := monHeight * HeightScale

	; Scale the non-base factor by the scale of the deviation from 16:9
	if (horizResNormFactor != vertResNormFactor) {
		; MsgBox, % "horiz: " . horizResNormFactor . " vert: " . vertResNormFactor
		if (vertResNormFactor = baseResNormFactor) {
			targetWidth *= horizResNormFactor * (1/baseResNormFactor) 
		} else if (horizResNormFactor = baseResNormFactor) {
			targetHeight *= vertResNormFactor * (1/baseResNormFactor)
		}
	}
	
	WinMove, %WinTitle%,,,, targetWidth, targetHeight
}

