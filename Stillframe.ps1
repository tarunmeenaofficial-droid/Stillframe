# Stillframe. Double-click Stillframe.bat. No install. No network.
$ErrorActionPreference = 'Stop'
$script:Self = $PSCommandPath
if (-not $script:Self) { $script:Self = $MyInvocation.MyCommand.Path }
$env:STILLFRAME_SCRIPT = $script:Self
$src = @'
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Text;
using System.Windows.Forms;
using Microsoft.Win32;

namespace Stillframe
{
    static class Native
    {
        public const int WM_HOTKEY = 0x0312;
        public const int WM_CLIPBOARDUPDATE = 0x031D;
        public const int MOD_ALT = 0x0001;
        public const int MOD_CONTROL = 0x0002;
        public const int MOD_SHIFT = 0x0004;
        public const int MOD_WIN = 0x0008;
        public const int MOD_NOREPEAT = 0x4000;
        public const int SW_MINIMIZE = 6;
        public const int SW_RESTORE = 9;
        public const int GWL_EXSTYLE = -20;
        public const int WS_EX_TOOLWINDOW = 0x00000080;
        public const int WS_EX_APPWINDOW = 0x00040000;
        public const uint GA_ROOT = 2;
        public const uint EVENT_SYSTEM_FOREGROUND = 0x0003;
        public const uint EVENT_SYSTEM_MINIMIZESTART = 0x0016;
        public const uint EVENT_OBJECT_DESTROY = 0x8001;
        public const uint WINEVENT_OUTOFCONTEXT = 0;
        public const uint PROCESS_QUERY_LIMITED_INFORMATION = 0x1000;

        public delegate bool EnumProc(IntPtr hWnd, IntPtr lParam);

        [UnmanagedFunctionPointer(CallingConvention.StdCall)]
        public delegate void WinEventDelegate(IntPtr hWinEventHook, uint eventType, IntPtr hwnd, int idObject, int idChild, uint dwEventThread, uint dwmsEventTime);

        [DllImport("user32.dll")]
        public static extern bool SetProcessDPIAware();
        [DllImport("user32.dll")]
        public static extern bool RegisterHotKey(IntPtr hWnd, int id, int fsModifiers, int vk);
        [DllImport("user32.dll")]
        public static extern bool UnregisterHotKey(IntPtr hWnd, int id);
        [DllImport("user32.dll")]
        public static extern bool AddClipboardFormatListener(IntPtr hwnd);
        [DllImport("user32.dll")]
        public static extern bool RemoveClipboardFormatListener(IntPtr hwnd);
        [DllImport("user32.dll")]
        public static extern IntPtr GetForegroundWindow();
        [DllImport("user32.dll")]
        public static extern IntPtr GetAncestor(IntPtr hwnd, uint gaFlags);
        [DllImport("user32.dll")]
        public static extern bool IsWindow(IntPtr hWnd);
        [DllImport("user32.dll")]
        public static extern bool IsWindowVisible(IntPtr hWnd);
        [DllImport("user32.dll")]
        public static extern bool IsIconic(IntPtr hWnd);
        [DllImport("user32.dll")]
        public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
        [DllImport("user32.dll")]
        public static extern bool SetForegroundWindow(IntPtr hWnd);
        [DllImport("user32.dll")]
        public static extern bool BringWindowToTop(IntPtr hWnd);
        [DllImport("user32.dll")]
        public static extern bool AllowSetForegroundWindow(int dwProcessId);
        [DllImport("user32.dll")]
        public static extern bool AttachThreadInput(uint idAttach, uint idAttachTo, bool fAttach);
        [DllImport("user32.dll")]
        public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);
        [DllImport("user32.dll")]
        public static extern bool EnumWindows(EnumProc lpEnumFunc, IntPtr lParam);
        [DllImport("user32.dll", CharSet = CharSet.Unicode)]
        public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);
        [DllImport("user32.dll", CharSet = CharSet.Unicode)]
        public static extern int GetClassName(IntPtr hWnd, StringBuilder lpClassName, int nMaxCount);
        [DllImport("user32.dll", EntryPoint = "GetWindowLong", CharSet = CharSet.Unicode)]
        public static extern int GetWindowLong32(IntPtr hWnd, int nIndex);
        [DllImport("user32.dll", EntryPoint = "GetWindowLongPtr", CharSet = CharSet.Unicode)]
        public static extern IntPtr GetWindowLongPtr64(IntPtr hWnd, int nIndex);
        [DllImport("user32.dll")]
        public static extern IntPtr SetWinEventHook(uint eventMin, uint eventMax, IntPtr hmodWinEventProc, WinEventDelegate lpfnWinEventProc, uint idProcess, uint idThread, uint dwFlags);
        [DllImport("user32.dll")]
        public static extern bool UnhookWinEvent(IntPtr hWinEventHook);
        [DllImport("user32.dll", CharSet = CharSet.Unicode)]
        public static extern IntPtr FindWindow(string lpClassName, string lpWindowName);
        [DllImport("kernel32.dll")]
        public static extern uint GetCurrentProcessId();
        [DllImport("kernel32.dll")]
        public static extern uint GetCurrentThreadId();
        [DllImport("kernel32.dll")]
        public static extern IntPtr OpenProcess(uint access, bool inherit, uint pid);
        [DllImport("kernel32.dll")]
        public static extern bool CloseHandle(IntPtr handle);
        [DllImport("kernel32.dll", CharSet = CharSet.Unicode)]
        public static extern bool QueryFullProcessImageName(IntPtr hProcess, int flags, StringBuilder name, ref int size);
        [DllImport("dwmapi.dll")]
        public static extern int DwmGetWindowAttribute(IntPtr hwnd, int attr, out int value, int size);
        [DllImport("shell32.dll", CharSet = CharSet.Unicode)]
        public static extern IntPtr SHGetFileInfo(string path, uint attr, ref SHFILEINFO info, uint cb, uint flags);
        [DllImport("user32.dll")]
        public static extern bool DestroyIcon(IntPtr handle);

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        public struct SHFILEINFO
        {
            public IntPtr hIcon;
            public int iIcon;
            public uint dwAttributes;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 260)]
            public string szDisplayName;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 80)]
            public string szTypeName;
        }

        public static long ExStyle(IntPtr hwnd)
        {
            if (IntPtr.Size == 8) return GetWindowLongPtr64(hwnd, GWL_EXSTYLE).ToInt64();
            return GetWindowLong32(hwnd, GWL_EXSTYLE);
        }

        public static string TextOf(IntPtr hwnd)
        {
            StringBuilder sb = new StringBuilder(512);
            GetWindowText(hwnd, sb, sb.Capacity);
            return sb.ToString();
        }

        public static string ClassOf(IntPtr hwnd)
        {
            StringBuilder sb = new StringBuilder(256);
            GetClassName(hwnd, sb, sb.Capacity);
            return sb.ToString();
        }

        public static bool Cloaked(IntPtr hwnd)
        {
            int value;
            if (DwmGetWindowAttribute(hwnd, 14, out value, 4) != 0) return false;
            return value != 0;
        }

        public static string ExeOf(uint pid)
        {
            IntPtr handle = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, false, pid);
            if (handle == IntPtr.Zero) return "";
            try
            {
                StringBuilder sb = new StringBuilder(1024);
                int size = sb.Capacity;
                if (!QueryFullProcessImageName(handle, 0, sb, ref size)) return "";
                return sb.ToString();
            }
            finally
            {
                CloseHandle(handle);
            }
        }

        public static void RevealDesktop()
        {
            try
            {
                Type shellType = Type.GetTypeFromProgID("Shell.Application");
                object shell = Activator.CreateInstance(shellType);
                shellType.InvokeMember("ToggleDesktop", BindingFlags.InvokeMethod, null, shell, new object[0]);
            }
            catch { }
        }

        public static bool Activate(IntPtr hwnd)
        {
            AllowSetForegroundWindow(-1);
            uint thisThread = GetCurrentThreadId();
            uint forePid;
            uint foreThread = GetWindowThreadProcessId(GetForegroundWindow(), out forePid);
            uint targetPid;
            uint targetThread = GetWindowThreadProcessId(hwnd, out targetPid);
            bool attachedFore = false;
            bool attachedTarget = false;
            try
            {
                if (foreThread != 0 && foreThread != thisThread) attachedFore = AttachThreadInput(thisThread, foreThread, true);
                if (targetThread != 0 && targetThread != thisThread) attachedTarget = AttachThreadInput(thisThread, targetThread, true);
                ShowWindow(hwnd, SW_RESTORE);
                BringWindowToTop(hwnd);
                return SetForegroundWindow(hwnd);
            }
            finally
            {
                if (attachedTarget) AttachThreadInput(thisThread, targetThread, false);
                if (attachedFore) AttachThreadInput(thisThread, foreThread, false);
            }
        }
    }

    public static class WindowPolicy
    {
        public static bool IsShell(string cls)
        {
            return cls == "Progman" || cls == "WorkerW" || cls == "Shell_TrayWnd" || cls == "Shell_SecondaryTrayWnd";
        }

        public static bool Keep(string cls, string title, uint pid, uint ourPid, bool toolOnly, bool self)
        {
            if (self) return false;
            if (pid == 0 || pid == ourPid) return false;
            if (IsShell(cls)) return false;
            if (toolOnly) return false;
            if (title == null || title.Trim().Length == 0) return false;
            return true;
        }
    }

    public class Hotkey
    {
        public bool Ctrl;
        public bool Alt;
        public bool Shift;
        public bool Win;
        public int Vk;

        public int Modifiers()
        {
            int mods = Native.MOD_NOREPEAT;
            if (Ctrl) mods |= Native.MOD_CONTROL;
            if (Alt) mods |= Native.MOD_ALT;
            if (Shift) mods |= Native.MOD_SHIFT;
            if (Win) mods |= Native.MOD_WIN;
            return mods;
        }

        public bool HasModifier()
        {
            return Ctrl || Alt || Shift || Win;
        }

        public override string ToString()
        {
            string text = "";
            if (Ctrl) text += "Ctrl+";
            if (Alt) text += "Alt+";
            if (Shift) text += "Shift+";
            if (Win) text += "Win+";
            text += KeyName(Vk);
            return text;
        }

        public static string KeyName(int vk)
        {
            if (vk >= 0x30 && vk <= 0x39) return ((char)vk).ToString();
            if (vk >= 0x41 && vk <= 0x5A) return ((char)vk).ToString();
            if (vk >= 0x70 && vk <= 0x7B) return "F" + (vk - 0x6F).ToString();
            return "Key" + vk.ToString();
        }

        public static bool TryParse(string text, out Hotkey hotkey)
        {
            hotkey = new Hotkey();
            if (text == null) return false;
            string[] parts = text.Split('+');
            if (parts.Length < 2) return false;
            for (int i = 0; i < parts.Length - 1; i++)
            {
                string part = parts[i].Trim();
                if (string.Equals(part, "Ctrl", StringComparison.OrdinalIgnoreCase)) hotkey.Ctrl = true;
                else if (string.Equals(part, "Alt", StringComparison.OrdinalIgnoreCase)) hotkey.Alt = true;
                else if (string.Equals(part, "Shift", StringComparison.OrdinalIgnoreCase)) hotkey.Shift = true;
                else if (string.Equals(part, "Win", StringComparison.OrdinalIgnoreCase)) hotkey.Win = true;
                else return false;
            }
            if (!hotkey.HasModifier()) return false;
            return TryKey(parts[parts.Length - 1].Trim(), out hotkey.Vk);
        }

        public static bool TryKey(string name, out int vk)
        {
            vk = 0;
            if (name == null || name.Length == 0) return false;
            if (name.Length == 1)
            {
                char c = char.ToUpperInvariant(name[0]);
                if (c >= 'A' && c <= 'Z') { vk = c; return true; }
                if (c >= '0' && c <= '9') { vk = c; return true; }
                return false;
            }
            if (name.Length >= 2 && (name[0] == 'F' || name[0] == 'f'))
            {
                int n;
                if (int.TryParse(name.Substring(1), out n) && n >= 1 && n <= 12)
                {
                    vk = 0x6F + n;
                    return true;
                }
            }
            return false;
        }
    }

    public class SettingsModel
    {
        public string MinimizeHotkey = "Ctrl+Y";
        public string DashboardHotkey = "Ctrl+Shift+Y";
        public bool StartWithWindows;
        public bool HideAfterRestore = true;
        public bool ClipboardHistory;
        public bool Diagnostics;
        public bool EveryWindow = true;
        public string Theme = "System";
    }

    public static class SettingsService
    {
        public static string Folder()
        {
            string dir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Stillframe");
            Directory.CreateDirectory(dir);
            return dir;
        }

        public static string PathOf()
        {
            return Path.Combine(Folder(), "settings.txt");
        }

        public static string Serialize(SettingsModel model)
        {
            return "minimize=" + model.MinimizeHotkey
                + "\ndashboard=" + model.DashboardHotkey
                + "\nstart=" + (model.StartWithWindows ? "1" : "0")
                + "\nhide=" + (model.HideAfterRestore ? "1" : "0")
                + "\nhistory=" + (model.ClipboardHistory ? "1" : "0")
                + "\nlog=" + (model.Diagnostics ? "1" : "0")
                + "\nevery=" + (model.EveryWindow ? "1" : "0")
                + "\ntheme=" + model.Theme + "\n";
        }

        public static SettingsModel Parse(string text)
        {
            SettingsModel model = new SettingsModel();
            if (text == null) return model;
            string[] lines = text.Split('\n');
            for (int i = 0; i < lines.Length; i++)
            {
                string line = lines[i].Trim();
                int cut = line.IndexOf('=');
                if (cut < 1) continue;
                string key = line.Substring(0, cut);
                string value = line.Substring(cut + 1);
                if (key == "minimize" && value.Length > 0) model.MinimizeHotkey = value;
                else if (key == "dashboard" && value.Length > 0) model.DashboardHotkey = value;
                else if (key == "start") model.StartWithWindows = value == "1";
                else if (key == "hide") model.HideAfterRestore = value != "0";
                else if (key == "history") model.ClipboardHistory = value == "1";
                else if (key == "log") model.Diagnostics = value == "1";
                else if (key == "every") model.EveryWindow = value != "0";
                else if (key == "theme" && value.Length > 0) model.Theme = value;
            }
            return model;
        }

        public static SettingsModel Load()
        {
            try
            {
                if (!File.Exists(PathOf())) return new SettingsModel();
                return Parse(File.ReadAllText(PathOf()));
            }
            catch
            {
                return new SettingsModel();
            }
        }

        public static void Save(SettingsModel model)
        {
            File.WriteAllText(PathOf(), Serialize(model));
        }
    }

    public static class DiagnosticsService
    {
        static bool enabled;

        public static void SetEnabled(bool on)
        {
            enabled = on;
        }

        public static void Log(string line)
        {
            if (!enabled || line == null) return;
            try
            {
                string path = Path.Combine(SettingsService.Folder(), "stillframe.log");
                File.AppendAllText(path, DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss") + " " + line + "\r\n");
            }
            catch { }
        }
    }

    public class ClipItem
    {
        public string Kind = "text";
        public string Preview = "";
        public string Text = "";
        public string Files = "";
    }

    public class ClipboardHistoryService
    {
        readonly List<ClipItem> items = new List<ClipItem>();
        readonly int max;

        public ClipboardHistoryService(int max)
        {
            this.max = max < 1 ? 1 : max;
        }

        public int Count { get { return items.Count; } }

        public string PreviewAt(int index)
        {
            if (index < 0 || index >= items.Count) return "";
            return items[index].Preview;
        }

        public ClipItem ItemAt(int index)
        {
            if (index < 0 || index >= items.Count) return null;
            return items[index];
        }

        public void AddText(string text)
        {
            if (text == null) return;
            string trimmed = text.Trim();
            if (trimmed.Length == 0) return;
            if (LooksSensitive(trimmed)) return;
            Add(new ClipItem { Kind = "text", Text = text, Preview = Short(trimmed) });
        }

        public void AddFiles(string files)
        {
            if (files == null || files.Trim().Length == 0) return;
            Add(new ClipItem { Kind = "files", Files = files, Preview = Short(files.Replace("\n", ", ")) });
        }

        public void AddImageNote()
        {
            Add(new ClipItem { Kind = "image", Preview = "[Image]" });
        }

        public void Clear()
        {
            items.Clear();
        }

        public static bool LooksSensitive(string text)
        {
            if (text.IndexOf("Password", StringComparison.OrdinalIgnoreCase) >= 0 && text.Length < 80) return true;
            return false;
        }

        void Add(ClipItem item)
        {
            if (items.Count > 0 && items[0].Preview == item.Preview && items[0].Kind == item.Kind) return;
            items.Insert(0, item);
            while (items.Count > max) items.RemoveAt(items.Count - 1);
        }

        static string Short(string text)
        {
            if (text.Length <= 80) return text;
            return text.Substring(0, 77) + "...";
        }
    }

    class TrackedWindow
    {
        public IntPtr Hwnd;
        public uint Pid;
        public string Title = "";
        public string Exe = "";
        public string Program = "";
        public bool Minimized;
        public DateTime LastActive = DateTime.Now;
    }

    class ApplicationRegistry
    {
        readonly List<TrackedWindow> rows = new List<TrackedWindow>();

        public int Count { get { return rows.Count; } }
        public TrackedWindow At(int index) { return rows[index]; }

        public TrackedWindow Find(IntPtr hwnd)
        {
            for (int i = 0; i < rows.Count; i++) if (rows[i].Hwnd == hwnd) return rows[i];
            return null;
        }

        public void Upsert(TrackedWindow row)
        {
            TrackedWindow existing = Find(row.Hwnd);
            if (existing == null) rows.Add(row);
            else
            {
                existing.Title = row.Title;
                existing.Exe = row.Exe;
                existing.Program = row.Program;
                existing.Pid = row.Pid;
                existing.Minimized = row.Minimized;
                existing.LastActive = row.LastActive;
            }
        }

        public void Remove(IntPtr hwnd)
        {
            for (int i = rows.Count - 1; i >= 0; i--) if (rows[i].Hwnd == hwnd) rows.RemoveAt(i);
        }

        public void Sort()
        {
            rows.Sort(delegate (TrackedWindow a, TrackedWindow b) { return b.LastActive.CompareTo(a.LastActive); });
        }

        public List<TrackedWindow> Visible(string query, bool everyWindow)
        {
            Sort();
            List<TrackedWindow> list = new List<TrackedWindow>();
            Dictionary<string, bool> seen = new Dictionary<string, bool>();
            string needle = query == null ? "" : query.Trim().ToLowerInvariant();
            for (int i = 0; i < rows.Count; i++)
            {
                TrackedWindow row = rows[i];
                if (needle.Length > 0)
                {
                    string hay = (row.Title + " " + row.Program).ToLowerInvariant();
                    if (hay.IndexOf(needle) < 0) continue;
                }
                if (!everyWindow)
                {
                    string key = row.Program.Length > 0 ? row.Program : row.Pid.ToString();
                    if (seen.ContainsKey(key)) continue;
                    seen[key] = true;
                }
                list.Add(row);
            }
            return list;
        }
    }

    public static class SelfTest
    {
        public static int Failures()
        {
            int failed = 0;
            Hotkey hotkey;
            if (!Hotkey.TryParse("Ctrl+Y", out hotkey) || !hotkey.Ctrl || hotkey.Alt || hotkey.Shift || hotkey.Win || hotkey.Vk != 0x59) failed++;
            if (!Hotkey.TryParse("Ctrl+Shift+F5", out hotkey) || !hotkey.Ctrl || !hotkey.Shift || hotkey.Vk != 0x74) failed++;
            if (Hotkey.TryParse("Y", out hotkey)) failed++;
            if (!WindowPolicy.Keep("Chrome_WidgetWin_1", "Mail", 10, 2, false, false)) failed++;
            if (WindowPolicy.Keep("Progman", "Desktop", 10, 2, false, false)) failed++;
            if (WindowPolicy.Keep("Notepad", "   ", 10, 2, false, false)) failed++;
            if (WindowPolicy.Keep("Notepad", "Notes", 2, 2, false, false)) failed++;
            if (WindowPolicy.Keep("Notepad", "Notes", 10, 2, true, false)) failed++;
            if (WindowPolicy.Keep("Notepad", "Notes", 10, 2, false, true)) failed++;
            ClipboardHistoryService history = new ClipboardHistoryService(3);
            history.AddText("a");
            history.AddText("b");
            history.AddText("c");
            history.AddText("d");
            if (history.Count != 3 || history.PreviewAt(0) != "d") failed++;
            if (!ClipboardHistoryService.LooksSensitive("my password")) failed++;
            SettingsModel model = new SettingsModel();
            model.MinimizeHotkey = "Ctrl+J";
            model.ClipboardHistory = true;
            model.EveryWindow = false;
            SettingsModel back = SettingsService.Parse(SettingsService.Serialize(model));
            if (back.MinimizeHotkey != "Ctrl+J" || !back.ClipboardHistory || back.EveryWindow) failed++;
            return failed;
        }
    }

    class MainForm : Form
    {
        const int HOTKEY_MINIMIZE = 1;
        const int HOTKEY_DASHBOARD = 2;
        readonly ApplicationRegistry registry = new ApplicationRegistry();
        readonly ClipboardHistoryService history = new ClipboardHistoryService(30);
        readonly Dictionary<string, int> iconIndex = new Dictionary<string, int>();
        readonly ImageList images = new ImageList();
        SettingsModel settings;
        ListView list;
        TextBox search;
        Label status;
        ListBox clipList;
        Button restoreButton;
        Button copyButton;
        Label clipHint;
        NotifyIcon tray;
        Timer reconcile;
        IntPtr eventHook;
        Native.WinEventDelegate eventProc;
        bool quitting;
        bool ignoreClipboard;
        bool clipboardOn;
        int lastHotkey;

        public MainForm()
        {
            settings = SettingsService.Load();
            DiagnosticsService.SetEnabled(settings.Diagnostics);
            Text = "Stillframe";
            ShowInTaskbar = true;
            StartPosition = FormStartPosition.CenterScreen;
            ClientSize = new Size(980, 600);
            MinimumSize = new Size(760, 480);
            Font = new Font(SystemFonts.MessageBoxFont.FontFamily, 9f);

            search = new TextBox();
            search.Dock = DockStyle.Fill;
            search.TextChanged += delegate { Fill(); };

            restoreButton = new Button();
            restoreButton.Text = "Restore";
            restoreButton.Dock = DockStyle.Right;
            restoreButton.Width = 96;
            restoreButton.Click += delegate { RestoreSelected(); };

            Button refreshButton = new Button();
            refreshButton.Text = "Refresh";
            refreshButton.Dock = DockStyle.Right;
            refreshButton.Width = 96;
            refreshButton.Click += delegate { Discover(); };

            Button settingsButton = new Button();
            settingsButton.Text = "Settings";
            settingsButton.Dock = DockStyle.Right;
            settingsButton.Width = 96;
            settingsButton.Click += delegate { OpenSettings(); };

            Panel top = new Panel();
            top.Dock = DockStyle.Top;
            top.Height = 44;
            top.Padding = new Padding(8, 8, 8, 8);
            top.Controls.Add(search);
            top.Controls.Add(restoreButton);
            top.Controls.Add(refreshButton);
            top.Controls.Add(settingsButton);

            list = new ListView();
            list.Dock = DockStyle.Fill;
            list.View = View.Details;
            list.FullRowSelect = true;
            list.HideSelection = false;
            list.MultiSelect = false;
            list.Columns.Add("Application", 340);
            list.Columns.Add("Status", 120);
            list.Columns.Add("Program", 180);
            images.ImageSize = new Size(16, 16);
            images.ColorDepth = ColorDepth.Depth32Bit;
            list.SmallImageList = images;
            list.DoubleClick += delegate { RestoreSelected(); };
            list.SelectedIndexChanged += delegate { restoreButton.Enabled = list.SelectedItems.Count > 0; };

            clipHint = new Label();
            clipHint.Dock = DockStyle.Top;
            clipHint.Height = 48;
            clipHint.Text = "Clipboard history is off. Ctrl+C and Ctrl+V are unchanged.";

            clipList = new ListBox();
            clipList.Dock = DockStyle.Fill;

            copyButton = new Button();
            copyButton.Text = "Copy again";
            copyButton.Dock = DockStyle.Left;
            copyButton.Width = 120;
            copyButton.Click += delegate { CopyHistory(); };

            Button clearButton = new Button();
            clearButton.Text = "Clear";
            clearButton.Dock = DockStyle.Right;
            clearButton.Width = 120;
            clearButton.Click += delegate { history.Clear(); FillHistory(); };

            Panel clipButtons = new Panel();
            clipButtons.Dock = DockStyle.Bottom;
            clipButtons.Height = 36;
            clipButtons.Controls.Add(copyButton);
            clipButtons.Controls.Add(clearButton);

            Panel side = new Panel();
            side.Dock = DockStyle.Right;
            side.Width = 280;
            side.Padding = new Padding(8);
            side.Controls.Add(clipList);
            side.Controls.Add(clipHint);
            side.Controls.Add(clipButtons);

            status = new Label();
            status.Dock = DockStyle.Bottom;
            status.Height = 32;
            status.TextAlign = ContentAlignment.MiddleLeft;
            status.Text = "Ctrl+Y minimizes the window you are in and shows the desktop.";
            restoreButton.Enabled = false;

            Controls.Add(list);
            Controls.Add(side);
            Controls.Add(top);
            Controls.Add(status);

            tray = new NotifyIcon();
            tray.Icon = SystemIcons.Application;
            tray.Visible = true;
            tray.Text = "Stillframe";
            ContextMenuStrip menu = new ContextMenuStrip();
            menu.Items.Add("Open Stillframe", null, delegate { ShowMe(); });
            menu.Items.Add("Restart as admin", null, delegate { RestartAdmin(); });
            menu.Items.Add("Exit", null, delegate { ExitClean(); });
            tray.ContextMenuStrip = menu;
            tray.DoubleClick += delegate { ShowMe(); };

            ApplyTheme();
            ApplyHistoryUi();
            reconcile = new Timer();
            reconcile.Interval = 2000;
            reconcile.Tick += delegate { Discover(); };
            reconcile.Start();
        }

        protected override void OnHandleCreated(EventArgs e)
        {
            base.OnHandleCreated(e);
            try { Native.SetProcessDPIAware(); } catch { }
            RegisterBoth();
            eventProc = OnWinEvent;
            eventHook = Native.SetWinEventHook(Native.EVENT_SYSTEM_FOREGROUND, Native.EVENT_SYSTEM_FOREGROUND, IntPtr.Zero, eventProc, 0, 0, Native.WINEVENT_OUTOFCONTEXT);
            minHook = Native.SetWinEventHook(Native.EVENT_SYSTEM_MINIMIZESTART, Native.EVENT_SYSTEM_MINIMIZESTART, IntPtr.Zero, eventProc, 0, 0, Native.WINEVENT_OUTOFCONTEXT);
            extraHook = Native.SetWinEventHook(Native.EVENT_OBJECT_DESTROY, Native.EVENT_OBJECT_DESTROY, IntPtr.Zero, eventProc, 0, 0, Native.WINEVENT_OUTOFCONTEXT);
            if (settings.ClipboardHistory) EnableClipboard(true);
            Discover();
            DiagnosticsService.Log("started");
        }

        IntPtr extraHook;
        IntPtr minHook;

        void ShowMe()
        {
            Show();
            WindowState = FormWindowState.Normal;
            Native.Activate(Handle);
            Discover();
        }

        void RegisterBoth()
        {
            try { Native.UnregisterHotKey(Handle, HOTKEY_MINIMIZE); } catch { }
            try { Native.UnregisterHotKey(Handle, HOTKEY_DASHBOARD); } catch { }
            Hotkey minimize;
            if (!Hotkey.TryParse(settings.MinimizeHotkey, out minimize))
            {
                settings.MinimizeHotkey = "Ctrl+Y";
                Hotkey.TryParse(settings.MinimizeHotkey, out minimize);
            }
            if (!Native.RegisterHotKey(Handle, HOTKEY_MINIMIZE, minimize.Modifiers(), minimize.Vk))
            {
                Hotkey alt = new Hotkey();
                alt.Ctrl = true;
                alt.Shift = true;
                alt.Vk = 0x59;
                if (Native.RegisterHotKey(Handle, HOTKEY_MINIMIZE, alt.Modifiers(), alt.Vk))
                {
                    settings.MinimizeHotkey = alt.ToString();
                    SettingsService.Save(settings);
                    status.Text = "Ctrl+Y was already in use. The shortcut is now " + alt.ToString() + ".";
                    DiagnosticsService.Log("hotkey moved to " + alt.ToString());
                }
                else status.Text = "Could not register a minimize shortcut. Change it in Settings.";
            }
            Hotkey dash;
            if (!Hotkey.TryParse(settings.DashboardHotkey, out dash))
            {
                settings.DashboardHotkey = "Ctrl+Shift+Y";
                Hotkey.TryParse(settings.DashboardHotkey, out dash);
            }
            if (dash.ToString() == settings.MinimizeHotkey) dash.Vk = 0x4A;
            if (!Native.RegisterHotKey(Handle, HOTKEY_DASHBOARD, dash.Modifiers(), dash.Vk))
            {
                status.Text = "Open Stillframe from the icon by the clock. The dashboard shortcut is in use.";
            }
            else settings.DashboardHotkey = dash.ToString();
        }

        protected override void WndProc(ref Message m)
        {
            if (m.Msg == Native.WM_HOTKEY)
            {
                int now = Environment.TickCount;
                if (unchecked(now - lastHotkey) < 250) return;
                lastHotkey = now;
                if (m.WParam.ToInt32() == HOTKEY_MINIMIZE) MinimizeActive();
                else if (m.WParam.ToInt32() == HOTKEY_DASHBOARD) ShowMe();
                return;
            }
            if (m.Msg == Native.WM_CLIPBOARDUPDATE && clipboardOn && !ignoreClipboard) CaptureClipboard();
            base.WndProc(ref m);
        }

        void MinimizeActive()
        {
            IntPtr hwnd = Native.GetAncestor(Native.GetForegroundWindow(), Native.GA_ROOT);
            if (hwnd == IntPtr.Zero) hwnd = Native.GetForegroundWindow();
            if (hwnd == Handle)
            {
                status.Text = "Stillframe stays open.";
                return;
            }
            if (!Eligible(hwnd))
            {
                status.Text = "That window cannot be minimized from here.";
                DiagnosticsService.Log("skip ineligible window");
                return;
            }
            bool ok = Native.ShowWindow(hwnd, Native.SW_MINIMIZE);
            if (!ok && !Native.IsIconic(hwnd))
            {
                status.Text = "Windows did not minimize that window.";
                DiagnosticsService.Log("minimize failed");
                return;
            }
            Remember(hwnd, true);
            Native.RevealDesktop();
            status.Text = "Minimized. The program is still running. Open Stillframe and click Restore.";
            DiagnosticsService.Log("minimized " + Native.TextOf(hwnd));
            Fill();
        }

        bool Eligible(IntPtr hwnd)
        {
            if (!Native.IsWindow(hwnd)) return false;
            if (!Native.IsWindowVisible(hwnd) && !Native.IsIconic(hwnd)) return false;
            if (Native.Cloaked(hwnd)) return false;
            long ex = Native.ExStyle(hwnd);
            bool toolOnly = (ex & Native.WS_EX_TOOLWINDOW) != 0 && (ex & Native.WS_EX_APPWINDOW) == 0;
            uint pid;
            Native.GetWindowThreadProcessId(hwnd, out pid);
            return WindowPolicy.Keep(Native.ClassOf(hwnd), Native.TextOf(hwnd), pid, Native.GetCurrentProcessId(), toolOnly, hwnd == Handle);
        }

        void Remember(IntPtr hwnd, bool minimized)
        {
            uint pid;
            Native.GetWindowThreadProcessId(hwnd, out pid);
            string exe = Native.ExeOf(pid);
            TrackedWindow row = new TrackedWindow();
            row.Hwnd = hwnd;
            row.Pid = pid;
            row.Title = Native.TextOf(hwnd);
            row.Exe = exe;
            row.Program = exe.Length == 0 ? "" : Path.GetFileName(exe);
            row.Minimized = minimized || Native.IsIconic(hwnd);
            row.LastActive = DateTime.Now;
            registry.Upsert(row);
        }

        void Discover()
        {
            if (!IsHandleCreated) return;
            List<IntPtr> found = new List<IntPtr>();
            Native.EnumProc callback = delegate (IntPtr hwnd, IntPtr lp)
            {
                if (Eligible(hwnd)) found.Add(hwnd);
                return true;
            };
            Native.EnumWindows(callback, IntPtr.Zero);
            Dictionary<long, bool> live = new Dictionary<long, bool>();
            for (int i = 0; i < found.Count; i++)
            {
                Remember(found[i], Native.IsIconic(found[i]));
                live[found[i].ToInt64()] = true;
            }
            for (int i = registry.Count - 1; i >= 0; i--)
            {
                TrackedWindow row = registry.At(i);
                if (!live.ContainsKey(row.Hwnd.ToInt64()) || !Native.IsWindow(row.Hwnd)) registry.Remove(row.Hwnd);
            }
            Fill();
        }

        void Fill()
        {
            if (list == null) return;
            long selected = 0;
            if (list.SelectedItems.Count > 0) selected = (long)list.SelectedItems[0].Tag;
            list.BeginUpdate();
            list.Items.Clear();
            List<TrackedWindow> rows = registry.Visible(search.Text, settings.EveryWindow);
            for (int i = 0; i < rows.Count; i++)
            {
                TrackedWindow row = rows[i];
                ListViewItem item = new ListViewItem(row.Title);
                item.SubItems.Add(row.Minimized ? "Minimized" : "Running");
                item.SubItems.Add(row.Program);
                item.ImageIndex = IconFor(row.Exe);
                item.Tag = row.Hwnd.ToInt64();
                list.Items.Add(item);
                if (row.Hwnd.ToInt64() == selected) item.Selected = true;
            }
            list.EndUpdate();
            restoreButton.Enabled = list.SelectedItems.Count > 0;
        }

        int IconFor(string exe)
        {
            if (exe == null || exe.Length == 0 || !File.Exists(exe)) return -1;
            int index;
            if (iconIndex.TryGetValue(exe, out index)) return index;
            Native.SHFILEINFO info = new Native.SHFILEINFO();
            IntPtr got = Native.SHGetFileInfo(exe, 0, ref info, (uint)Marshal.SizeOf(typeof(Native.SHFILEINFO)), 0x100 | 0x1);
            if (got == IntPtr.Zero || info.hIcon == IntPtr.Zero) return -1;
            try
            {
                Icon icon = Icon.FromHandle(info.hIcon);
                images.Images.Add((Icon)icon.Clone());
                int at = images.Images.Count - 1;
                iconIndex[exe] = at;
                return at;
            }
            catch
            {
                return -1;
            }
            finally
            {
                Native.DestroyIcon(info.hIcon);
            }
        }

        void RestoreSelected()
        {
            if (list.SelectedItems.Count == 0) return;
            long key = (long)list.SelectedItems[0].Tag;
            IntPtr hwnd = new IntPtr(key);
            TrackedWindow row = registry.Find(hwnd);
            if (!Native.IsWindow(hwnd))
            {
                if (row != null) registry.Remove(hwnd);
                Fill();
                status.Text = "That window has already closed.";
                return;
            }
            bool focused = Native.Activate(hwnd);
            if (row != null)
            {
                row.Minimized = Native.IsIconic(hwnd);
                row.LastActive = DateTime.Now;
            }
            if (!focused)
            {
                status.Text = "The window was restored. Windows did not let Stillframe focus it. Click it on the taskbar if it is not in front.";
                DiagnosticsService.Log("foreground restricted");
            }
            else
            {
                status.Text = "Restored.";
                DiagnosticsService.Log("restored");
            }
            if (settings.HideAfterRestore) Hide();
            else Fill();
        }

        void OnWinEvent(IntPtr hook, uint type, IntPtr hwnd, int idObject, int idChild, uint thread, uint time)
        {
            if (idObject != 0 || hwnd == IntPtr.Zero) return;
            try
            {
                BeginInvoke((MethodInvoker)delegate
                {
                    IntPtr root = Native.GetAncestor(hwnd, Native.GA_ROOT);
                    if (root == IntPtr.Zero) root = hwnd;
                    if (type == Native.EVENT_OBJECT_DESTROY)
                    {
                        if (registry.Find(root) != null)
                        {
                            registry.Remove(root);
                            if (Visible) Fill();
                        }
                        return;
                    }
                    if (!Eligible(root) && registry.Find(root) == null) return;
                    if (type == Native.EVENT_SYSTEM_MINIMIZESTART) Remember(root, true);
                    else Remember(root, Native.IsIconic(root));
                    if (Visible) Fill();
                });
            }
            catch { }
        }

        void EnableClipboard(bool on)
        {
            if (!IsHandleCreated) return;
            if (on && !clipboardOn)
            {
                clipboardOn = Native.AddClipboardFormatListener(Handle);
            }
            else if (!on && clipboardOn)
            {
                Native.RemoveClipboardFormatListener(Handle);
                clipboardOn = false;
            }
            ApplyHistoryUi();
        }

        void ApplyHistoryUi()
        {
            bool on = settings.ClipboardHistory;
            clipList.Visible = on;
            copyButton.Enabled = on;
            clipHint.Text = on
                ? "Local clipboard history. Normal Ctrl+C and Ctrl+V still use the Windows clipboard."
                : "Clipboard history is off. Ctrl+C and Ctrl+V are unchanged.";
        }

        void CaptureClipboard()
        {
            try
            {
                IDataObject data = Clipboard.GetDataObject();
                if (data == null) return;
                string[] formats = data.GetFormats();
                if (formats != null)
                {
                    for (int i = 0; i < formats.Length; i++)
                    {
                        if (formats[i] != null && formats[i].IndexOf("Password", StringComparison.OrdinalIgnoreCase) >= 0) return;
                    }
                }
                if (data.GetDataPresent(DataFormats.UnicodeText))
                {
                    object value = data.GetData(DataFormats.UnicodeText);
                    if (value is string) history.AddText((string)value);
                }
                else if (data.GetDataPresent(DataFormats.FileDrop))
                {
                    string[] files = data.GetData(DataFormats.FileDrop) as string[];
                    if (files != null) history.AddFiles(string.Join("\n", files));
                }
                else if (data.GetDataPresent(DataFormats.Bitmap)) history.AddImageNote();
                FillHistory();
            }
            catch
            {
                DiagnosticsService.Log("clipboard busy");
            }
        }

        void FillHistory()
        {
            clipList.Items.Clear();
            for (int i = 0; i < history.Count; i++) clipList.Items.Add(history.PreviewAt(i));
        }

        void CopyHistory()
        {
            if (clipList.SelectedIndex < 0) return;
            ClipItem item = history.ItemAt(clipList.SelectedIndex);
            if (item == null) return;
            try
            {
                ignoreClipboard = true;
                if (item.Kind == "text") Clipboard.SetText(item.Text);
                else if (item.Kind == "files")
                {
                    System.Collections.Specialized.StringCollection bag = new System.Collections.Specialized.StringCollection();
                    string[] parts = item.Files.Split('\n');
                    for (int i = 0; i < parts.Length; i++) if (parts[i].Length > 0) bag.Add(parts[i]);
                    Clipboard.SetFileDropList(bag);
                }
                else
                {
                    status.Text = "That image was only noted. Copy it again from the original program.";
                    return;
                }
                status.Text = "Copied back to the Windows clipboard.";
            }
            catch
            {
                status.Text = "The clipboard was busy. Try again.";
            }
            finally
            {
                ignoreClipboard = false;
            }
        }

        void OpenSettings()
        {
            using (SettingsForm dialog = new SettingsForm(settings))
            {
                if (dialog.ShowDialog(this) != DialogResult.OK) return;
                settings = dialog.Result;
                SettingsService.Save(settings);
                DiagnosticsService.SetEnabled(settings.Diagnostics);
                ApplyStartup();
                RegisterBoth();
                EnableClipboard(settings.ClipboardHistory);
                if (!settings.ClipboardHistory) history.Clear();
                ApplyTheme();
                Fill();
                FillHistory();
            }
        }

        void ApplyStartup()
        {
            try
            {
                using (RegistryKey key = Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Run", true))
                {
                    if (key == null) return;
                    if (!settings.StartWithWindows)
                    {
                        key.DeleteValue("Stillframe", false);
                        return;
                    }
                    string launch = Environment.GetEnvironmentVariable("STILLFRAME_BAT");
                    if (launch == null || launch.Length == 0) launch = Environment.GetEnvironmentVariable("STILLFRAME_SCRIPT");
                    if (launch == null || launch.Length == 0) return;
                    key.SetValue("Stillframe", "\"" + launch + "\"");
                }
            }
            catch
            {
                status.Text = "Could not change the Windows startup setting.";
            }
        }

        void ApplyTheme()
        {
            bool dark = settings.Theme == "Dark";
            Color back = dark ? Color.FromArgb(32, 32, 32) : SystemColors.Window;
            Color fore = dark ? Color.White : SystemColors.WindowText;
            BackColor = dark ? Color.FromArgb(24, 24, 24) : SystemColors.Control;
            ForeColor = fore;
            list.BackColor = back;
            list.ForeColor = fore;
            search.BackColor = back;
            search.ForeColor = fore;
            clipList.BackColor = back;
            clipList.ForeColor = fore;
            status.ForeColor = fore;
        }

        void RestartAdmin()
        {
            try
            {
                string script = Environment.GetEnvironmentVariable("STILLFRAME_SCRIPT");
                if (script == null || script.Length == 0)
                {
                    status.Text = "Start Stillframe from Stillframe.bat, then try admin again.";
                    return;
                }
                ProcessStartInfo info = new ProcessStartInfo();
                info.FileName = "powershell.exe";
                info.Arguments = "-NoProfile -ExecutionPolicy Bypass -STA -File \"" + script + "\"";
                info.Verb = "runas";
                info.UseShellExecute = true;
                Process.Start(info);
                ExitClean();
            }
            catch
            {
                status.Text = "Admin start was cancelled.";
            }
        }

        void ExitClean()
        {
            quitting = true;
            Close();
        }

        protected override void OnFormClosing(FormClosingEventArgs e)
        {
            if (!quitting && e.CloseReason == CloseReason.UserClosing)
            {
                e.Cancel = true;
                Hide();
                return;
            }
            reconcile.Stop();
            try { Native.UnregisterHotKey(Handle, HOTKEY_MINIMIZE); } catch { }
            try { Native.UnregisterHotKey(Handle, HOTKEY_DASHBOARD); } catch { }
            if (clipboardOn) Native.RemoveClipboardFormatListener(Handle);
            if (eventHook != IntPtr.Zero) Native.UnhookWinEvent(eventHook);
            if (minHook != IntPtr.Zero) Native.UnhookWinEvent(minHook);
            if (extraHook != IntPtr.Zero) Native.UnhookWinEvent(extraHook);
            tray.Visible = false;
            base.OnFormClosing(e);
        }
    }

    class SettingsForm : Form
    {
        public SettingsModel Result;
        TextBox minimizeBox;
        TextBox dashboardBox;
        CheckBox startBox;
        CheckBox hideBox;
        CheckBox historyBox;
        CheckBox everyBox;
        CheckBox logBox;
        ComboBox themeBox;

        public SettingsForm(SettingsModel current)
        {
            Result = current;
            Text = "Settings";
            FormBorderStyle = FormBorderStyle.FixedDialog;
            StartPosition = FormStartPosition.CenterParent;
            MinimizeBox = false;
            MaximizeBox = false;
            ClientSize = new Size(440, 360);
            Font = new Font(SystemFonts.MessageBoxFont.FontFamily, 9f);

            Label hint = new Label();
            hint.SetBounds(16, 12, 408, 32);
            hint.Text = "Shortcuts need a modifier, like Ctrl+Y or Ctrl+Shift+J.";

            minimizeBox = Box("Minimize shortcut", current.MinimizeHotkey, 52);
            dashboardBox = Box("Open Stillframe", current.DashboardHotkey, 96);
            startBox = Check("Start with Windows", current.StartWithWindows, 140);
            hideBox = Check("Hide Stillframe after restore", current.HideAfterRestore, 166);
            historyBox = Check("Clipboard history", current.ClipboardHistory, 192);
            everyBox = Check("Show every window, not one row per program", current.EveryWindow, 218);
            logBox = Check("Diagnostic log (no clipboard text)", current.Diagnostics, 244);

            themeBox = new ComboBox();
            themeBox.DropDownStyle = ComboBoxStyle.DropDownList;
            themeBox.SetBounds(160, 274, 160, 24);
            themeBox.Items.Add("System");
            themeBox.Items.Add("Light");
            themeBox.Items.Add("Dark");
            themeBox.SelectedItem = current.Theme == "Dark" || current.Theme == "Light" ? current.Theme : "System";
            Label themeLabel = new Label();
            themeLabel.Text = "Theme";
            themeLabel.SetBounds(16, 276, 130, 22);

            Button ok = new Button();
            ok.Text = "Save";
            ok.SetBounds(236, 316, 88, 28);
            ok.Click += delegate { Save(); };
            Button cancel = new Button();
            cancel.Text = "Cancel";
            cancel.SetBounds(332, 316, 88, 28);
            cancel.DialogResult = DialogResult.Cancel;
            AcceptButton = ok;
            CancelButton = cancel;

            Controls.Add(hint);
            Controls.Add(themeLabel);
            Controls.Add(themeBox);
            Controls.Add(ok);
            Controls.Add(cancel);
        }

        TextBox Box(string label, string value, int top)
        {
            Label caption = new Label();
            caption.Text = label;
            caption.SetBounds(16, top, 140, 22);
            TextBox box = new TextBox();
            box.Text = value;
            box.SetBounds(160, top - 2, 250, 24);
            Controls.Add(caption);
            Controls.Add(box);
            return box;
        }

        CheckBox Check(string label, bool value, int top)
        {
            CheckBox box = new CheckBox();
            box.Text = label;
            box.Checked = value;
            box.SetBounds(16, top, 400, 22);
            Controls.Add(box);
            return box;
        }

        void Save()
        {
            Hotkey unused;
            if (!Hotkey.TryParse(minimizeBox.Text.Trim(), out unused) || !Hotkey.TryParse(dashboardBox.Text.Trim(), out unused))
            {
                MessageBox.Show(this, "Use a shortcut with a modifier, such as Ctrl+Y.", "Stillframe");
                return;
            }
            Result.MinimizeHotkey = minimizeBox.Text.Trim();
            Result.DashboardHotkey = dashboardBox.Text.Trim();
            Result.StartWithWindows = startBox.Checked;
            Result.HideAfterRestore = hideBox.Checked;
            Result.ClipboardHistory = historyBox.Checked;
            Result.EveryWindow = everyBox.Checked;
            Result.Diagnostics = logBox.Checked;
            Result.Theme = themeBox.SelectedItem == null ? "System" : themeBox.SelectedItem.ToString();
            DialogResult = DialogResult.OK;
        }
    }

    public static class Program
    {
        static System.Threading.Mutex mutex;

        [STAThread]
        public static void Main()
        {
            int failed = SelfTest.Failures();
            if (failed != 0)
            {
                MessageBox.Show("Stillframe self-check failed (" + failed.ToString() + ").", "Stillframe");
                return;
            }
            bool created;
            mutex = new System.Threading.Mutex(true, "Local\\Stillframe.Single", out created);
            if (!created) return;
            try { Native.SetProcessDPIAware(); } catch { }
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Application.Run(new MainForm());
            try { mutex.ReleaseMutex(); } catch { }
        }
    }
}

'@

try {
  $splat = @{
    TypeDefinition = $src
    ReferencedAssemblies = @('System.Windows.Forms','System.Drawing')
    Language = 'CSharp'
  }
  $cmd = Get-Command Add-Type -ErrorAction SilentlyContinue
  if ($cmd -and $cmd.Parameters.ContainsKey('IgnoreWarnings')) { $splat['IgnoreWarnings'] = $true }
  Add-Type @splat
  [Stillframe.Program]::Main()
} catch {
  $msg = $_.Exception.Message
  if ($_.Exception.InnerException) { $msg = $msg + [Environment]::NewLine + $_.Exception.InnerException.Message }
  try { Add-Type -AssemblyName System.Windows.Forms } catch {}
  [System.Windows.Forms.MessageBox]::Show($msg, 'Stillframe')
}
