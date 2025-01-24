function run_test {
    param (
        [string]$name,
        [string]$command,
        [string]$expected_output
    )

    $global:TOTAL_TESTS++
    Write-Host -NoNewline "Testing $name... "

    try {
        $script:output = Invoke-Expression "$global:GITHUB_WORKSPACE/ffmpeg.exe $command 2>&1" | Out-String
        if ($script:output -cmatch $expected_output) {
            Write-Host "✅ PASSED"
            $global:PASSED_TESTS++
        } else {
            Write-Host "❌ FAILED"
            $global:FAILED_TESTS++
        }
    } catch {
        Write-Host "❌ FAILED (Error)"
        $global:FAILED_TESTS++
    }
}