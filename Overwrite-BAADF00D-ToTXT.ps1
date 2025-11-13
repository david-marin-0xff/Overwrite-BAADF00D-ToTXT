<#
  Overwrite-BAADF00D-ToTXT.ps1
  Educational script: overwrite file with repeating 0xBA 0xAD 0xF0 0x0D pattern for N passes,
  then create a .txt file showing the pattern.
  Use only on files you own and for testing.
#>

function Prompt-FilePath {
    while ($true) {
        $p = Read-Host "Enter full path to the file you want to overwrite (or type 'exit' to quit)"
        if ($p -eq 'exit') { throw "User cancelled." }
        if (-not (Test-Path -Path $p -PathType Leaf)) {
            Write-Warning "File not found: $p`nPlease enter a valid file path."
            continue
        }
        return (Resolve-Path -Path $p).Path
    }
}

function Prompt-Passes {
    while ($true) {
        $s = Read-Host "How many overwrite passes do you want to perform? (Enter a positive integer, e.g., 3)"
        if (-not [int]::TryParse($s, [ref]$null)) {
            Write-Warning "Please enter a whole number."
            continue
        }
        $n = [int]$s
        if ($n -lt 1) {
            Write-Warning "Number of passes must be at least 1."
            continue
        }
        return $n
    }
}

try {
    Write-Host "=== BAADF00D Multi-pass Overwriter (educational) ===`n" -ForegroundColor Cyan

    $path = Prompt-FilePath
    $passes = Prompt-Passes

    $pattern = [byte[]](0xBA,0xAD,0xF0,0x0D)
    $blockSize = 4KB
    $block = New-Object byte[] $blockSize
    for ($i = 0; $i -lt $block.Length; $i += $pattern.Length) {
        $block[$i]   = $pattern[0]
        $block[$i+1] = $pattern[1]
        $block[$i+2] = $pattern[2]
        $block[$i+3] = $pattern[3]
    }

    Write-Host "`nOpening file: $path"
    $fileInfo = Get-Item -LiteralPath $path
    Write-Host ("File size: {0:N0} bytes" -f $fileInfo.Length)

    for ($pass = 1; $pass -le $passes; $pass++) {
        Write-Host "`nStarting pass $pass of $passes ..." -ForegroundColor Yellow

        $fs = [System.IO.File]::Open($path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
        try {
            $size = $fs.Length
            $written = 0
            while ($written -lt $size) {
                $remaining = $size - $written
                $toWrite = if ($remaining -ge $block.Length) { $block } else {
                    $partial = New-Object byte[] $remaining
                    [Array]::Copy($block, 0, $partial, 0, $remaining)
                    $partial
                }
                $fs.Write($toWrite, 0, $toWrite.Length)
                $fs.Flush()
                try { $fs.Flush([System.IO.FlushOption]::FlushToDisk) } catch {}
                $written += $toWrite.Length

                $percent = [int](100.0 * $written / $size)
                Write-Progress -Activity "Pass $pass / $passes ? Overwriting" -Status ("{0:N0}/{1:N0} bytes" -f $written, $size) -PercentComplete $percent
            }
            Write-Host "Pass $pass complete. Flushed." -ForegroundColor Green
        }
        finally {
            $fs.Close()
        }
        Start-Sleep -Milliseconds 200
    }

    # Build readable text file next to the original
    $txtPath = [System.IO.Path]::ChangeExtension($path, ".txt")
    Write-Host "`nWriting readable text version to: $txtPath"

    $patternString = "BA AD F0 0D "
    $repeatCount = [math]::Ceiling($fileInfo.Length / 4)
    $content = ($patternString * $repeatCount).Trim()

    Set-Content -Path $txtPath -Value $content -Encoding ASCII

    Write-Host "`nDone! The original file was overwritten $passes time(s) with BA AD F0 0D."
    Write-Host "A readable version was created at: $txtPath" -ForegroundColor Cyan
}
catch {
    Write-Error "Operation cancelled or failed: $($_.Exception.Message)"
}
