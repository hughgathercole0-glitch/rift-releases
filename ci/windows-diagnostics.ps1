$ErrorActionPreference='Continue'
Add-Type @'
using System;
using System.Collections.Generic;
using System.Text;
using System.Runtime.InteropServices;
public static class RiftWindows {
 public delegate bool Callback(IntPtr h,IntPtr l);
 [DllImport("user32.dll")] static extern bool EnumWindows(Callback c,IntPtr p);
 [DllImport("user32.dll")] static extern bool EnumChildWindows(IntPtr h,Callback c,IntPtr p);
 [DllImport("user32.dll",CharSet=CharSet.Unicode)] static extern int GetWindowText(IntPtr h,StringBuilder s,int n);
 [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h,out uint p);
 public static List<string> Read(uint[] pids){var result=new List<string>();EnumWindows((h,l)=>{uint pid;GetWindowThreadProcessId(h,out pid);if(Array.IndexOf(pids,pid)<0)return true;var s=new StringBuilder(2048);GetWindowText(h,s,s.Capacity);result.Add(pid+": "+s);EnumChildWindows(h,(child,x)=>{var t=new StringBuilder(2048);GetWindowText(child,t,t.Capacity);if(t.Length>0)result.Add("  "+t);return true;},IntPtr.Zero);return true;},IntPtr.Zero);return result;}
}
'@
$processes=@(Get-CimInstance Win32_Process|Where-Object {$_.Name -match 'RIFT|good|Uninstall|nsis'})
$processes|Select-Object Name,ProcessId,ParentProcessId,ExecutablePath,CommandLine|ConvertTo-Json -Depth 3|Set-Content validation/installer-processes.json
$ids=@($processes|ForEach-Object{[uint32]$_.ProcessId})
[RiftWindows]::Read([uint32[]]$ids)|Set-Content validation/installer-windows.log
try {Add-Type -AssemblyName System.Windows.Forms;Add-Type -AssemblyName System.Drawing;$bounds=[System.Windows.Forms.Screen]::PrimaryScreen.Bounds;$bitmap=New-Object System.Drawing.Bitmap($bounds.Width,$bounds.Height);$graphics=[System.Drawing.Graphics]::FromImage($bitmap);$graphics.CopyFromScreen($bounds.Location,[System.Drawing.Point]::Empty,$bounds.Size);$bitmap.Save((Join-Path $PWD 'validation/installer-desktop.png'));$graphics.Dispose();$bitmap.Dispose()}catch {Write-Output 'No interactive Windows screenshot available'}
