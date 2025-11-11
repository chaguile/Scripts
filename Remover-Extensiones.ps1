

# ================================================
# Script: Buscar y eliminar archivos/carpetas por criterios
# ================================================

Write-Host "---------------------------------------------------"
Write-Host " Aviso de Licencia y Responsabilidad" -ForegroundColor Yellow
Write-Host "---------------------------------------------------"
Write-Host "Este script se entrega bajo licencia MIT, con derecho de uso,"
Write-Host "copia, modificacion y distribucion, siempre que este aviso se mantenga."
Write-Host ""
Write-Host "Esta herramienta esta destinada UNICAMENTE a ubicar y eliminar"
Write-Host "archivos y carpetas en sistemas donde usted tiene autorizacion."
Write-Host ""
Write-Host "Al ejecutar este script, usted confirma que:"
Write-Host " - Esta autorizado para eliminar los archivos y carpetas seleccionados."
Write-Host " - Entiende que las eliminaciones son permanentes y pueden no ser recuperables."
Write-Host " - Acepta la responsabilidad total de verificar que se eliminara."
Write-Host ""
Write-Host "ESTE SCRIPT SE ENTREGA 'TAL CUAL', SIN NINGUN TIPO DE GARANTIA."
Write-Host "EL USO ES BAJO EXCLUSIVA RESPONSABILIDAD DEL USUARIO FINAL."
Write-Host "---------------------------------------------------"
Write-Host ""

# ===== VERIFICAR PERMISOS DE ADMINISTRADOR =====
$windowsIdentity  = [Security.Principal.WindowsIdentity]::GetCurrent()
$windowsPrincipal = New-Object Security.Principal.WindowsPrincipal($windowsIdentity)
$isAdmin = $windowsPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host ""
    Write-Host "ERROR: Este script debe ejecutarse usando permisos administrativos." -ForegroundColor Red
    Write-Host "Por favor cierre esta ventana y abra PowerShell usando 'Ejecutar como administrador'." -ForegroundColor Yellow
    Write-Host ""
    return
}

Write-Host ""
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host "   BUSCADOR Y ELIMINADOR DE ARCHIVOS Y CARPETAS" -ForegroundColor Cyan
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "IMPORTANTE:" -ForegroundColor Yellow
Write-Host " - Cuando use rutas en PowerShell, si la ruta contiene espacios debe estar entre comillas." -ForegroundColor Yellow
Write-Host ""

# ===== DATOS DEL ENTORNO =====
$equipoOrigen  = $env:COMPUTERNAME
$cuentaUsuario = $env:USERNAME

# ===== ENTRADA DE USUARIO =====
$RootPath = Read-Host "Ingrese la ruta de la carpeta a revisar"
$includeSubfolders = Read-Host "Desea incluir subcarpetas? (S/N)"
$extInput = Read-Host "Ingrese las extensiones de archivo a buscar, separadas por coma (ejemplo: .zip,.mov,.exe,.doc,.docx). Deje vacio si no desea usar extensiones"
$fileNameInput = Read-Host "Ingrese nombres de archivo completos a buscar, separados por coma (ejemplo: virus.exe,malware.bat). Deje vacio si no desea usar nombres de archivo"
$folderNameInput = Read-Host "Ingrese nombres de carpeta a buscar, separados por coma (ejemplo: temp,logs,backup). Deje vacio si no desea usar nombres de carpeta"

# Limpiar comillas si el usuario las puso
$RootPath = $RootPath.Trim('"')

# Procesar extensiones
$Extensions = @()
if (-not [string]::IsNullOrWhiteSpace($extInput)) {
    $Extensions = $extInput.Split(",") | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }

    # Normalizar extensiones: asegurar que empiezan con punto
    $Extensions = $Extensions | ForEach-Object {
        if (-not $_.StartsWith(".")) { "." + $_ } else { $_ }
    }
}

# Procesar nombres de archivo
$FileNames = @()
if (-not [string]::IsNullOrWhiteSpace($fileNameInput)) {
    $FileNames = $fileNameInput.Split(",") | ForEach-Object { $_.Trim().ToLower() } | Where-Object { $_ -ne "" }
}

# Procesar nombres de carpeta
$FolderNames = @()
if (-not [string]::IsNullOrWhiteSpace($folderNameInput)) {
    $FolderNames = $folderNameInput.Split(",") | ForEach-Object { $_.Trim().ToLower() } | Where-Object { $_ -ne "" }
}

if (($Extensions.Count -eq 0) -and ($FileNames.Count -eq 0) -and ($FolderNames.Count -eq 0)) {
    Write-Host "No se ingresaron extensiones, nombres de archivo ni nombres de carpeta validos. Operacion cancelada." -ForegroundColor Yellow
    return
}

Write-Host ""
if ($Extensions.Count -gt 0) {
    Write-Host "Extensiones a buscar: $($Extensions -join ", ")" -ForegroundColor Cyan
}
if ($FileNames.Count -gt 0) {
    Write-Host "Nombres de archivo a buscar: $($FileNames -join ", ")" -ForegroundColor Cyan
}
if ($FolderNames.Count -gt 0) {
    Write-Host "Nombres de carpeta a buscar: $($FolderNames -join ", ")" -ForegroundColor Cyan
}
Write-Host ""

# ===== DEFINIR RUTA DE LOG AUTOMATICA =====
$timestamp = Get-Date -Format "yyyyMMddHHmmss"
$logDir = "C:\Windows\Temp"
$LogPath = Join-Path $logDir ("Remover-Extensiones-{0}.csv" -f $timestamp)

# ===== BUSCAR ELEMENTOS =====
Write-Host ""
Write-Host "Escaneando carpeta: $RootPath" -ForegroundColor Cyan
Write-Host ""

if ($includeSubfolders.ToUpper() -in @("S", "SI", "Y", "YES")) {
    $items = Get-ChildItem -Path $RootPath -Recurse
} else {
    $items = Get-ChildItem -Path $RootPath
}

# Archivos que cumplen criterios (extension y/o nombre)
$files = $items | Where-Object {
    -not $_.PSIsContainer -and (
        ($Extensions.Count -gt 0 -and $Extensions -contains $_.Extension.ToLower()) -or
        ($FileNames.Count -gt 0 -and $FileNames -contains $_.Name.ToLower())
    )
}

# Carpetas que cumplen criterios (nombre de carpeta)
$folders = $items | Where-Object {
    $_.PSIsContainer -and
    ($FolderNames.Count -gt 0 -and $FolderNames -contains $_.Name.ToLower())
}

$targets = @()
if ($files)   { $targets += $files }
if ($folders) { $targets += $folders }

if (-not $targets -or $targets.Count -eq 0) {
    Write-Host "No se encontraron archivos ni carpetas que coincidan con los criterios especificados." -ForegroundColor Yellow
    return
}

Write-Host "Los siguientes elementos fueron encontrados:" -ForegroundColor Green
Write-Host ""
$targets | Select-Object `
    @{Name="Tipo";Expression={ if ($_.PSIsContainer) { "Carpeta" } else { "Archivo" } }},
    FullName, Name, Extension, Length, LastWriteTime |
    Format-Table -AutoSize

# ===== CONFIRMACION =====
$confirm = Read-Host "`nDesea eliminar estos elementos (archivos y/o carpetas)? (S/N)"

if ($confirm.ToUpper() -notin @("S", "SI", "Y", "YES")) {
    Write-Host "Operacion cancelada. No se eliminaron elementos." -ForegroundColor Yellow
    return
}

# ===== NOMBRE DE QUIEN AUTORIZA =====
$authorizer = Read-Host "Ingrese el nombre de la persona que autoriza la eliminacion"

if ([string]::IsNullOrWhiteSpace($authorizer)) {
    Write-Host "No se proporciono nombre de autorizacion. Operacion cancelada." -ForegroundColor Yellow
    return
}

$now = Get-Date

# ===== ELIMINAR Y REGISTRAR =====
$logRows = @()

foreach ($item in $targets) {
    try {
        if ($item.PSIsContainer) {
            # Eliminar carpeta completa (recursivo)
            Remove-Item -LiteralPath $item.FullName -Recurse -Force
            $tipoElemento = "Carpeta"
        } else {
            # Eliminar archivo
            Remove-Item -LiteralPath $item.FullName -Force
            $tipoElemento = "Archivo"
        }

        $logRows += [PSCustomObject]@{
            TipoElemento         = $tipoElemento
            AutorizadoPor        = $authorizer
            FechaEliminacion     = $now
            RutaElemento         = $item.FullName
            NombreElemento       = $item.Name
            ExtensionElemento    = $item.Extension
            TamanoBytes          = $item.Length
            UltimaModificacion   = $item.LastWriteTime
            EquipoOrigen         = $equipoOrigen
            CuentaUsuario        = $cuentaUsuario
            ExtensionesUsadas    = ($Extensions -join ", ")
            NombresArchivoUsados = ($FileNames -join ", ")
            NombresCarpetaUsados = ($FolderNames -join ", ")
            IncluyeSubcarpetas   = ($includeSubfolders.ToUpper() -in @("S","SI","Y","YES"))
            CarpetaRaizAnalizada = $RootPath
        }
    }
    catch {
        Write-Host "Error al eliminar: $($item.FullName) - $($_.Exception.Message)" -ForegroundColor Red
    }
}

if ($logRows.Count -gt 0) {
    try {
        if (-not (Test-Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }

        $logRows | Export-Csv -Path $LogPath -NoTypeInformation

        Write-Host ""
        Write-Host "Elementos eliminados registrados en: $LogPath" -ForegroundColor Cyan
    }
    catch {
        Write-Host ""
        Write-Host "Los elementos fueron eliminados, pero se produjo un error al escribir el archivo de registro:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }
} else {
    Write-Host "No se eliminaron elementos. No se genero registro." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Proceso completado." -ForegroundColor Green
