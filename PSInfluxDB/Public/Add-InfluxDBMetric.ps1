
function Add-InfluxDBMetric {
    [cmdletbinding(SupportsShouldProcess = $true)]
    param(
        #[parameter(Mandatory, ValueFromPipeline = $true)]
        #[psobject[]]$InputObject,

        [parameter(Mandatory)]
        [string]$SeriesName,

        [parameter(Mandatory)]
        [string]$Endpoint,

        [switch]$Https,

        [parameter(Mandatory)]
        [string]$Database,

        [validateSet('n', 'u', 'ms', 's', 'm', 'h')]
        [string]$precision = 's',

        [string]$RetentionPolicy,

        [validateSet('any', 'one', 'quorum', 'all')]
        [string]$Consistency,

        [int]$RequestTimeout = 5,

        [string]$UserAgent,

        [psobject]$Tags,

        [parameter(Mandatory, ValueFromPipeline = $true)]
        [psobject]$Counters,

        [datetime]$Time = (Get-Date),

        [int]$Port = 8086,

        [pscredential]$Credential,

        [switch]$PassThru
    )

    begin {
        function Escape($value) {
            return ($value -Replace ',', '\,' -Replace ' ', '\ ' -Replace '=', '\ =')
        }

        # Unix time
        $unixTime = [int][double]::Parse($(Get-Date -date ($Time).ToUniversalTime()-uformat %s))

        # Setup the URL to POST to
        if ($PSBoundParameters.ContainsKey('Https')) {
            $url = "https://$endpoint"
        } else {
            $url = "http://$endpoint"
        }
        $url += ":$port/write?db=$Database&precision=$precision"
        if ($PSBoundParameters.ContainsKey('RetentionPolicy')) {
            $url += "&rp=$RetentionPolicy"
        }
        if ($PSBoundParameters.ContainsKey('Consistency')) {
            $url += "&consistency=$Consistency"
        }

        $params = @{
            Uri = $url
            Method = 'POST'
            UseBasicParsing = $true
            Timeout = $RequestTimeout
        }
        if ($PSBoundParameters.ContainsKey('Credential')) {
            $params.Credential = $Credential
        }
        if ($PSBoundParameters.ContainsKey('UserAgent')) {
            $params.UserAgent = $UserAgent
        }

        $metrics = New-Object System.Collections.ArrayList
    }

    process {
        #foreach ($item in $InputObject) {
            # Pull out any tag properties from object
            #if ($TagPropertyName.Count -gt 0) {
            #    $tags = ($item | Get-Member -MemberType NoteProperty | where Name -NotIn $TagPropertyName).Name
            #}

            # This will be the measurement name in InfluxDB
            #$measurementName = $item.$MeasurementPropertyName

            # Counters will be all remaining properties from InputObject that are
            # not tags or the measurement name
            #$counters = $item | Get-Member -MemberType NoteProperty | where Name -NotIn $tags
            #$counters = ($counters | Where-Object { $_ -ne $MeasurementPropertyName }).Name

            $metric = $SeriesName
            if ($PSBoundParameters.ContainsKey('Tags')) {
                foreach ($tag in ($Tags | Get-Member -MemberType NoteProperty).Name) {
                    $metric += ",$tag=$(Escape($Tags.$tag))"
                }
            }
            $metric += ' '

            foreach ($counter in ($Counters | Get-Member -MemberType NoteProperty).Name) {
                $metric += "$counter=$(Escape($Counters.$counter)),"
            }
            $metric = $metric.TrimEnd(',')
            $metric += " $unixTime"

            $metrics.Add($metric) | Out-Null
            Write-Debug -Message $metric

            foreach ($line in $metrics) {
                $params.Body = $line
            }

            if ($PSCmdlet.ShouldProcess($url)) {
                $result = Invoke-RestMethod @params

                if ($PSBoundParameters.ContainsKey('PassThru')) {
                    $result
                }
            }
        #}
    }

    end {}
}