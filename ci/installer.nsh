; Repair only the exact unsigned uninstallers shipped in RIFT 0.6.0/0.6.1.
; The replacement is the new installer's own correctly generated uninstaller.
; CRC and publisher verification remain enabled. User data is never removed.
!macro customInit
 !ifndef BUILD_UNINSTALLER
  IfFileExists "$INSTDIR\Uninstall RIFT.exe" 0 rift_repair_done
  ${StdUtils.HashFile} $R0 "SHA2-256" "$INSTDIR\Uninstall RIFT.exe"
  ${If} $R0 == "EF7923D499381091496060457AD780BA37DB245D8B242F8C5ACB529B8C4006BD"
  ${OrIf} $R0 == "CA0EE21BAE995517404587D8B146913A64FB0D229C7146BBCCD56E8AF7C1F2A0"
   InitPluginsDir
   File /oname=$PLUGINSDIR\rift-preview-repair.exe "${UNINSTALLER_OUT_FILE}"
   IfFileExists "$INSTDIR\rift-preview-uninstaller.bak" rift_repair_failed 0
   ClearErrors
   CopyFiles /SILENT "$PLUGINSDIR\rift-preview-repair.exe" "$INSTDIR\rift-preview-uninstaller.new"
   IfErrors rift_repair_failed
   Rename "$INSTDIR\Uninstall RIFT.exe" "$INSTDIR\rift-preview-uninstaller.bak"
   IfErrors rift_repair_failed
   Rename "$INSTDIR\rift-preview-uninstaller.new" "$INSTDIR\Uninstall RIFT.exe"
   IfErrors 0 rift_repair_done
   Rename "$INSTDIR\rift-preview-uninstaller.bak" "$INSTDIR\Uninstall RIFT.exe"
   Goto rift_repair_failed
  ${EndIf}
  Goto rift_repair_done
  rift_repair_failed:
   MessageBox MB_OK|MB_ICONSTOP "RIFT could not repair this preview's uninstaller. Your saved data has been retained. Close other installers and retry." /SD IDOK
   SetErrorLevel 2
   Quit
  rift_repair_done:
 !endif
!macroend
