function corsproxy
{
  param (
    [int]$Port = 8080,
    [string]$LogDir = $null,
    [switch]$NoLog,
    [switch]$ShowAll
  )

  # --- Fix Encoding for PowerShell 5.1 ---
  if ($PSVersionTable.PSVersion.Major -le 5)
  {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    [Console]::InputEncoding = [System.Text.Encoding]::UTF8
    $OutputEncoding = [System.Text.Encoding]::UTF8
    Add-Type -AssemblyName System.Net.Http
  }

  $CurrentScriptRoot = $PSScriptRoot
  . (Join-Path $CurrentScriptRoot "constants.ps1")

  if (-not $LogDir)
  { $LogDir = $NoxProxyLogDir
  }

  # --- Localization ---
  $Lang = if (Test-Path $NoxLangFile)
  { (Get-Content $NoxLangFile -Raw -Encoding UTF8).Trim()
  } else
  { "en"
  }
  $I18nPath = Join-Path $NoxI18nDir "$Lang.json"
  if (-not (Test-Path $I18nPath))
  { $I18nPath = Join-Path $NoxI18nDir "en.json"
  }

  $Messages = Get-Content $I18nPath -Raw -Encoding UTF8 | ConvertFrom-Json
  function Get-Msg($Key)
  { return $Messages.corsproxy.$Key
  }

  if (-not $NoLog)
  {
    if (Test-Path $LogDir)
    { Remove-Item -Path $LogDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
  }

  $Host.UI.RawUI.WindowTitle = "CORS Proxy :$Port"
  Clear-Host
  Write-Host "==========================================" -ForegroundColor Cyan
  Write-Host ("            " + (Get-Msg Title)) -ForegroundColor White
  Write-Host "==========================================" -ForegroundColor Cyan

  Write-Host (" " + (Get-Msg Portal)) -NoNewline -ForegroundColor DarkGray
  Write-Host "$Port" -ForegroundColor Cyan

  if ($NoLog)
  {
    Write-Host (" " + (Get-Msg Records)) -NoNewline -ForegroundColor DarkGray
    Write-Host (Get-Msg Sealed) -ForegroundColor Red
  } elseif ($ShowAll)
  {
    Write-Host (" " + (Get-Msg Aspect)) -NoNewline -ForegroundColor DarkGray
    Write-Host (Get-Msg Absolute) -ForegroundColor Green
  } else
  {
    Write-Host (" " + (Get-Msg Aspect)) -NoNewline -ForegroundColor DarkGray
    Write-Host (Get-Msg Whisper) -ForegroundColor Yellow
  }
  Write-Host "------------------------------------------" -ForegroundColor Gray

  $prefix = "http://localhost:$Port/"
  $listener = New-Object System.Net.HttpListener
  $listener.Prefixes.Add($prefix)

  $handler = New-Object System.Net.Http.HttpClientHandler
  # PS5 (.NET Framework) does not have DecompressionMethods.All; use GZip + Deflate instead
  $handler.AutomaticDecompression = [System.Net.DecompressionMethods]::GZip -bor [System.Net.DecompressionMethods]::Deflate
  $httpClient = New-Object System.Net.Http.HttpClient($handler)

  $reqId = 0

  try
  {
    $listener.Start()
    $contextTask = $null

    while ($listener.IsListening)
    {
      if ($null -eq $contextTask)
      { $contextTask = $listener.GetContextAsync()
      }
      if (-not $contextTask.AsyncWaitHandle.WaitOne(300))
      { continue
      }

      try
      {
        $context = $contextTask.Result
        $contextTask = $null
        $reqId++
      } catch
      { break
      }

      $request = $context.Request
      $response = $context.Response
      $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

      # CORS Headers
      $response.Headers.Add("Access-Control-Allow-Origin", "*")
      $response.Headers.Add("Access-Control-Allow-Methods", "*")
      $response.Headers.Add("Access-Control-Allow-Headers", "*")
      $response.Headers.Add("Access-Control-Expose-Headers", "*")

      if ($request.HttpMethod -eq "OPTIONS")
      {
        $response.StatusCode = 200; $response.Close(); continue
      }

      $targetUrl = $request.RawUrl.Substring(1)
      if ([string]::IsNullOrWhiteSpace($targetUrl) -or $targetUrl -eq "favicon.ico")
      {
        $response.StatusCode = 404; $response.Close(); continue
      }

      $logData = $null
      if (-not $NoLog)
      {
        $logData = [Ordered]@{
          Timestamp = Get-Date -Format "HH:mm:ss.fff";
          Method = $request.HttpMethod;
          FullUrl = $targetUrl
          RequestHeaders = @{};
          RequestBody = $null;
          ResponseStatus = 0;
          ResponseHeaders = @{};
          ResponseBody = $null;
          Duration = ""
        }
      }

      try
      {
        try
        { $uriObj = New-Object Uri $targetUrl; $cleanPath = $uriObj.AbsolutePath
        } catch
        { $cleanPath = $targetUrl
        }

        $httpMethod = New-Object System.Net.Http.HttpMethod($request.HttpMethod)
        $reqMsg = New-Object System.Net.Http.HttpRequestMessage($httpMethod, $targetUrl)

        # Headers to skip when forwarding
        $noiseHeaders = @("Host", "Connection", "Content-Length", "Expect", "Referer", "Accept-Encoding", "User-Agent", "Sec-Fetch-Dest", "Sec-Fetch-Site", "Sec-Fetch-Mode", "Sec-Fetch-User", "sec-ch-ua", "sec-ch-ua-mobile", "sec-ch-ua-platform", "Origin", "Accept", "Upgrade-Insecure-Requests", "Pragma", "Cache-Control", "DNT", "Cookie")

        foreach ($key in $request.Headers.AllKeys)
        {
          if ($key -in "Host", "Connection", "Content-Length", "Expect", "Referer", "Accept-Encoding")
          { continue
          }
          try
          {
            $val = $request.Headers[$key]
            $reqMsg.Headers.TryAddWithoutValidation($key, $val) | Out-Null

            if ($logData -and ($key -notin $noiseHeaders))
            {
              if ($key -eq "Authorization" -and $val.Length -gt 50)
              {
                $logData.RequestHeaders[$key] = $val.Substring(0, 30) + " ... [TRUNCATED] ... " + $val.Substring($val.Length - 10)
              } else
              { $logData.RequestHeaders[$key] = $val
              }
            }
          } catch
          {
          }
        }

        if ($request.HasEntityBody)
        {
          $memStream = New-Object System.IO.MemoryStream
          $request.InputStream.CopyTo($memStream); $memStream.Position = 0
          if ($logData)
          {
            $bodyStr = (New-Object System.IO.StreamReader($memStream, [System.Text.Encoding]::UTF8)).ReadToEnd()
            $logData.RequestBody = try
            { $bodyStr | ConvertFrom-Json
            } catch
            { $bodyStr
            }
            $memStream.Position = 0
          }
          $reqMsg.Content = New-Object System.Net.Http.StreamContent($memStream)
          if ($request.ContentType)
          { $reqMsg.Content.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse($request.ContentType)
          }
        }

        $targetResponse = $httpClient.SendAsync($reqMsg).Result
        $responseCode = [int]$targetResponse.StatusCode
        $response.StatusCode = $responseCode
        if ($targetResponse.Content.Headers.ContentType)
        { $response.ContentType = $targetResponse.Content.Headers.ContentType.ToString()
        }

        $respBytes = $targetResponse.Content.ReadAsByteArrayAsync().Result
        $response.ContentLength64 = $respBytes.Length
        $response.OutputStream.Write($respBytes, 0, $respBytes.Length)

        if ($logData)
        {
          $logData.ResponseStatus = "$responseCode ($($targetResponse.ReasonPhrase))"
          $respStr = [System.Text.Encoding]::UTF8.GetString($respBytes)
          $logData.ResponseBody = try
          { $respStr | ConvertFrom-Json
          } catch
          { $respStr
          }
        }

        $stopwatch.Stop()
        $isError = $responseCode -ge 400
        if ($ShowAll -or $isError)
        {
          $c = if ($responseCode -lt 300)
          { "Green"
          } elseif ($responseCode -lt 500)
          { "Yellow"
          } else
          { "Red"
          }

          Write-Host "[$($reqId)] " -NoNewline -ForegroundColor Magenta
          Write-Host "$(Get-Date -Format 'HH:mm:ss') " -NoNewline -ForegroundColor DarkGray
          Write-Host "$($request.HttpMethod) " -NoNewline -ForegroundColor Cyan
          Write-Host "$responseCode " -NoNewline -ForegroundColor $c
          Write-Host $cleanPath -ForegroundColor White

          if (-not $NoLog)
          {
            $logData.Duration = "{0:N0}ms" -f $stopwatch.Elapsed.TotalMilliseconds
            $safeName = ($cleanPath.TrimStart('/').Replace('/', '_') -replace '[^a-zA-Z0-9_\-\.]', '')
            if ([string]::IsNullOrWhiteSpace($safeName))
            { $safeName = "root"
            }
            $fileName = "{0}_{1}_{2}.json" -f $request.HttpMethod, ($safeName.Substring([Math]::Max(0, $safeName.Length - 50))), $reqId
            $filePath = Join-Path $LogDir $fileName
            $logData | ConvertTo-Json -Depth 10 | Set-Content -Path $filePath -Encoding UTF8

            # Clickable link (OSC 8)
            $esc = [char]27
            $fileUri = ([Uri]$filePath).AbsoluteUri
            $openText = Get-Msg Open
            $openLink = "$esc]8;;$fileUri$esc\[$openText]$esc]8;;$esc\"

            Write-Host "      └─ " -NoNewline -ForegroundColor DarkGray
            Write-Host $openLink -ForegroundColor White
          }
        }
      } catch
      { Write-Host "$(Get-Msg ErrPrefix) $_" -ForegroundColor Red; $response.StatusCode = 502
      } finally
      { try
        { $response.Close()
        } catch
        {
        }; if ($reqMsg)
        { $reqMsg.Dispose()
        }
      }
    }
  } finally
  { $listener.Stop(); $httpClient.Dispose(); Write-Host (Get-Msg Stopped) -ForegroundColor Yellow
  }
}
