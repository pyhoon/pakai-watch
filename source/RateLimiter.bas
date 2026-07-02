B4J=true
Group=Filters
ModulesStructureVersion=1
Type=Class
Version=10.5
@EndOfDesignText@
'Filter class
Sub Class_Globals
    ' Per-endpoint route configuration loaded from Main.GetRateLimitConfig
    Private RouteConfig As Map
    
    ' Default limits (used as fallback)
    Private MaxRequests As Int = 10
    Private WindowMs As Long = 10000
    
    ' Thread safety using ReentrantLock
    Private Lock As JavaObject
    
    ' Whitelist Settings
    Private Whitelist As B4XSet
    Private const WHITELIST_FILE As String = "whitelist.txt"
    
    ' Logging Settings
    Private const SECURITY_LOG_FILE As String = "security_violations.log"
    
    ' Periodic maintenance (every N requests)
    Private const CLEANUP_EVERY As Int = 100
    
    ' Per-API-key limit overrides (keyed by client identifier)
    Private KeyOverrides As Map
End Sub

Public Sub Initialize
    ' Initialize Lock
    Lock.InitializeNewInstance("java.util.concurrent.locks.ReentrantLock", Null)
    
    ' Initialize persistent state in Main module (singleton)
    If Main.RateLimiterRequestCounts.IsInitialized = False Then
        Main.RateLimiterRequestCounts.Initialize
    End If
    If Main.RateLimiterTotalBlocks = 0 Then Main.RateLimiterTotalBlocks = 0
    If Main.RateLimiterProcessed = 0 Then Main.RateLimiterProcessed = 0
    
    ' Initialize per-instance fields
    RouteConfig.Initialize
    KeyOverrides.Initialize
    Whitelist.Initialize
    LoadWhitelistFromFile
    
    ' Load per-endpoint limits from the main module if available
    If SubExists(Main, "GetRateLimitConfig") Then
        Dim Cfg As Map = CallSub(Main, "GetRateLimitConfig")
        If Cfg.IsInitialized And Cfg.Size > 0 Then
            If Cfg.ContainsKey("__key_overrides__") Then
                Dim Ko As Map = Cfg.Get("__key_overrides__")
                If Ko.IsInitialized And Ko.Size > 0 Then KeyOverrides = Ko
                Cfg.Remove("__key_overrides__")
            End If
            RouteConfig = Cfg
        End If
    End If
    
    ' Set the initial date tracking string
    DateTime.DateFormat = "yyyy-MM-dd"
    If Main.RateLimiterCurrentDate = "" Then
        Main.RateLimiterCurrentDate = DateTime.Date(DateTime.Now)
    End If
End Sub

' Converts a config value (List or int[]) to a proper List
Private Sub AsList (Value As Object) As List
    If Value Is List Then Return Value
	'Log(GetType(Value))
    Dim Arr() As Int = Value
    Dim L As List
    L.Initialize
    L.Add(Arr(0))
    L.Add(Arr(1))
    Return L
End Sub

' Sets MaxRequests/WindowMs using priority: key override > URI config > default
Private Sub ApplyLimits (URI As String, ClientIdentifier As String)
    ' 1. Check per-key override first (highest priority)
    If KeyOverrides.IsInitialized And KeyOverrides.Size > 0 And KeyOverrides.ContainsKey(ClientIdentifier) Then
        Dim Limits As List = AsList(KeyOverrides.Get(ClientIdentifier))
        If Limits.Size >= 2 Then
            MaxRequests = Limits.Get(0)
            WindowMs = Limits.Get(1)
            Return
        End If
    End If
    
    ' 2. Check per-URI route config
    If RouteConfig.IsInitialized And RouteConfig.Size > 0 Then
        For Each Pattern As String In RouteConfig.Keys
            If URI.StartsWith(Pattern) Then
                Dim Limits As List = AsList(RouteConfig.Get(Pattern))
                If Limits.Size >= 2 Then
                    MaxRequests = Limits.Get(0)
                    WindowMs = Limits.Get(1)
                    Return
                End If
            End If
        Next
    End If
    
    ' 3. Fallback to defaults
    MaxRequests = 10
    WindowMs = 10000
End Sub

' Filter event runs on incoming HTTP requests
Public Sub Filter (req As ServletRequest, resp As ServletResponse) As Boolean
    Dim ClientIdentifier As String = ""
    Dim AuthHeader As String = req.GetHeader("Authorization")
    
    If AuthHeader <> "" And AuthHeader <> Null Then
        If AuthHeader.StartsWith("Bearer ") Then
            ClientIdentifier = AuthHeader.SubString(7).Trim
        Else
            ClientIdentifier = AuthHeader.Trim
        End If
    End If
    
    Dim UserIP As String = req.GetHeader("CF-Connecting-IP")
    If UserIP = "" Or UserIP = Null Then UserIP = req.RemoteAddress
    
    If ClientIdentifier = "" Then ClientIdentifier = "GUEST-" & UserIP
    
    If IsWhitelisted(ClientIdentifier, UserIP) Then Return True
    
    ApplyLimits(req.RequestURI, ClientIdentifier)
    Return EnforceRateLimit(ClientIdentifier, req.RequestURI, resp)
End Sub

Private Sub AcquireLock
    Lock.RunMethod("lock", Null)
End Sub

Private Sub ReleaseLock
    Lock.RunMethod("unlock", Null)
End Sub

Private Sub LoadWhitelistFromFile
    Try
        If File.Exists(File.DirApp, WHITELIST_FILE) = False Then
            File.WriteList(File.DirApp, WHITELIST_FILE, Array As String("127.0.0.1"))
        End If
        
        Dim Lines As List = File.ReadList(File.DirApp, WHITELIST_FILE)
        
        Whitelist.Clear
        For Each Entry As String In Lines
            Dim CleanEntry As String = Entry.Trim
            If CleanEntry <> "" And CleanEntry.StartsWith("#") = False Then
                Whitelist.Add(CleanEntry)
            End If
        Next
    Catch
        Log("RateLimiter Error: Whitelist load failed: " & LastException.Message)
    End Try
End Sub

Private Sub LogViolation (Identifier As String, RequestPath As String)
    Dim LogLine As String = $"[${DateTime.Date(DateTime.Now)} ${DateTime.Time(DateTime.Now)}] BLOCKED: ID/IP [${Identifier}] spamming ${RequestPath}${CRLF}"$
    Try
        Dim Out As OutputStream = File.OpenOutput(File.DirApp, SECURITY_LOG_FILE, True)
        Dim tw As TextWriter
        tw.Initialize(Out)
        tw.Write(LogLine)
        tw.Close
        
        ' Increment the daily summary block counter
        Main.RateLimiterTotalBlocks = Main.RateLimiterTotalBlocks + 1
        
    Catch
        Log("RateLimiter Error: Failed to write to security log: " & LastException.Message)
    End Try
End Sub

' Helper method called by the background worker at midnight
Private Sub GenerateDailySummaryReport (ReportDate As String, BlocksCount As Int)
    Dim ReportFile As String = $"daily_report_${ReportDate}.txt"$
    Dim ReportContent As String = _
        $"=========================================${CRLF}"$ & _
        $"RATE LIMITER DAILY SUMMARY REPORT        ${CRLF}"$ & _
        $"Date: ${ReportDate}                     ${CRLF}"$ & _
        $"=========================================${CRLF}"$ & _
        $"Total Security Interceptions: ${BlocksCount}${CRLF}"$ & _
        $"Status: Completed                         ${CRLF}"$
        
    Try
        File.WriteString(File.DirApp, ReportFile, ReportContent)
        Log("RateLimiter Background Worker: Generated daily summary report file " & ReportFile)
    Catch
        Log("RateLimiter Error: Failed to generate summary report: " & LastException.Message)
    End Try
End Sub

Private Sub IsWhitelisted (Identifier As String, UserIP As String) As Boolean
    AcquireLock
    Try
        If Whitelist.Contains(Identifier) Or Whitelist.Contains(UserIP) Then
            ReleaseLock
            Return True
        End If
        
        ' B4XSet doesn't have Keys property - iterate through all items
        For Each Rule As String In Whitelist.AsList
            If Rule.Contains("*") Then
                Dim Prefix As String = Rule.Replace("*", "")
                If UserIP.StartsWith(Prefix) Then
                    ReleaseLock
                    Return True
                End If
            End If
        Next
        
        ReleaseLock
        Return False
    Catch
        Log("RateLimiter Error in IsWhitelisted: " & LastException.Message)
        ReleaseLock
        Return False
    End Try
End Sub

Private Sub EnforceRateLimit (Identifier As String, RequestURI As String, Resp As ServletResponse) As Boolean
    AcquireLock
    Try
        Dim Now As Long = DateTime.Now
        
        Dim RequestHistory As List
        Dim HadExisting As Boolean = Main.RateLimiterRequestCounts.ContainsKey(Identifier)
        
        If HadExisting Then
            RequestHistory = Main.RateLimiterRequestCounts.Get(Identifier)
        Else
            RequestHistory.Initialize
            Main.RateLimiterRequestCounts.Put(Identifier, RequestHistory)
        End If
        
        Dim CutoffTime As Long = Now - WindowMs
        Do While RequestHistory.Size > 0 And RequestHistory.Get(0) < CutoffTime
            RequestHistory.RemoveAt(0)
        Loop
        
        If RequestHistory.Size >= MaxRequests Then
            LogViolation(Identifier, RequestURI)
            
            Resp.Status = 429 
            Resp.SetHeader("Retry-After", NumberFormat(WindowMs / 1000, 1, 0))
            Resp.ContentType = "text/plain"
            Resp.Write("Too Many Requests. Please wait.")
            
            DoPeriodicMaintenance
            ReleaseLock
            Return False 
        End If
        
        RequestHistory.Add(Now)
        
        DoPeriodicMaintenance
        ReleaseLock
        Return True 
    Catch
        Log("RateLimiter Error in EnforceRateLimit: " & LastException.Message)
        ReleaseLock
        Return True
    End Try
End Sub

' Runs periodically inside EnforceRateLimit (inside the lock)
Private Sub DoPeriodicMaintenance
    Main.RateLimiterProcessed = Main.RateLimiterProcessed + 1
    If Main.RateLimiterProcessed < CLEANUP_EVERY Then Return
    
    Main.RateLimiterProcessed = 0
    
    LoadWhitelistFromFile
    
    ' Check if the calendar day has rolled over
    DateTime.DateFormat = "yyyy-MM-dd"
    Dim CheckTodayString As String = DateTime.Date(DateTime.Now)
    
    If CheckTodayString <> Main.RateLimiterCurrentDate Then
        GenerateDailySummaryReport(Main.RateLimiterCurrentDate, Main.RateLimiterTotalBlocks)
        Main.RateLimiterTotalBlocks = 0
        Main.RateLimiterCurrentDate = CheckTodayString
    End If
    
    ' Clean up stale IP histories from the Map
    Dim Now As Long = DateTime.Now
    Dim CutoffTime As Long = Now - WindowMs
    Dim IDsToRemove As List
    IDsToRemove.Initialize
    
    For Each Identifier As String In Main.RateLimiterRequestCounts.Keys
        Dim RequestHistory As List = Main.RateLimiterRequestCounts.Get(Identifier)
        
        Do While RequestHistory.Size > 0 And RequestHistory.Get(0) < CutoffTime
            RequestHistory.RemoveAt(0)
        Loop
        
        If RequestHistory.Size = 0 Then
            IDsToRemove.Add(Identifier)
        End If
    Next
    
    For Each InactiveID As String In IDsToRemove
        Main.RateLimiterRequestCounts.Remove(InactiveID)
    Next
End Sub
