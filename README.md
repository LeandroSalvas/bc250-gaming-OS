# BC-250 Gaming ISO — Arch Linux Customizada

## Descrição

Este projeto gera uma ISO do Arch Linux voltada para jogos na APU AMD BC-250
(gfx1013 / Cyan Skillfish). A ISO sobe um ambiente **Live** com KDE Plasma 6,
shell **Fish** como padrão, login automático do usuário `deck`, sudo sem senha
no Live e um atalho **“Instalar Agora!”** na área de trabalho que abre o
instalador gráfico **Calamares**.

O kernel, o driver de sensores, o governor e as ferramentas da comunidade
BC-250 já vêm pré-instalados *out-of-the-box*.

## O que está incluído

### Base e boot
- **linux-cachyos-bc250** — kernel CachyOS otimizado para a BC-250 (já inclui
  `nct6687.ko` para sensores/fans).
- `mkinitcpio` + `mkinitcpio-archiso`, `amd-ucode`, `linux-firmware`.
- Boot **BIOS (syslinux)** e **UEFI (systemd-boot)**.
- `memtest86+`, `edk2-shell`, `grub`, `efibootmgr`.

### Desktop e áudio
- **KDE Plasma 6** (`plasma-meta`, SDDM com autologin).
- **PipeWire** + WirePlumber, `pavucontrol`, ALSA.
- Firefox, Dolphin, Konsole, Kate, Ark, Gwenview, Spectacle.

### Stack de jogos
- **Steam**, **Gamemode** (+ lib32), **MangoHud** (+ lib32), **Gamescope**.
- **Mesa** e **Vulkan-Radeon** (incluindo lib32) dos repositórios CachyOS.
- **proton-cachyos-native-bc250** do repositório comunitário `bc250-cachyos`.

### Ferramentas BC-250
- **bc250-control-center-git** — central de monitoramento/ajuste/recovery
  (AUR, compilado no build).
- **cyan-skillfish-governor-smu** — governor de GPU para a Cyan Skillfish
  (AUR, compilado no build).
- **bc250-40cu-unlock** — scripts/patch de referência para reativar as 40 CUs.
- **bc250-core-unlock** — reativa os 2 núcleos de CPU desabilitados.
- **bc250-cu-live-manager** — gerenciador interativo de WGP/CU (requer `umr`).
- Pacotes do repositório `bc250-cachyos`: `bc250-fixes`, `bc250-cec`,
  `bc250-dual-audio`, `bc250-paccache-cleanup`, `bc250-vcn-fw`.

### Instalador
- **cachyos-calamares** com instalação **offline** via `unpackfs`: copia o
  SquashFS do Live para o disco, sem baixar pacotes.
- Configs customizadas em `airootfs/etc/calamares/modules/bc250-*.conf`
  (ESP em `/boot/efi`, GRUB, SDDM, serviços) e script
  `bc250-cleanup-target`, que remove os artefatos do Live do sistema instalado.

## Estrutura do Repositório

```
.
├── profiledef.sh                 # Definição do perfil archiso
├── packages.x86_64               # Lista de pacotes da ISO
├── pacman.conf                   # pacman.conf usado no BUILD (SigLevel=Never)
├── airootfs/                     # Overlay do sistema Live
│   ├── etc/
│   │   ├── calamares/
│   │   │   ├── settings.conf      # sequência offline (UnpackFS)
│   │   │   └── modules/bc250-*.conf
│   │   ├── modprobe.d/amdgpu.conf # ip_block_mask
│   │   ├── pacman.conf           # pacman.conf do sistema Live/instalado
│   │   ├── sddm.conf.d/          # autologin
│   │   ├── systemd/system/       # unidades e symlinks
│   │   ├── sudoers.d/deck        # NOPASSWD no Live
│   │   └── skel/                 # Fish, KDE, atalho "Instalar Agora!"
│   └── usr/local/bin/            # bc250-live-setup, bc250-load-modules,
│                                 # bc250-cleanup-target, ...
├── efiboot/                      # systemd-boot (UEFI)
├── grub/                         # GRUB
├── syslinux/                     # syslinux (BIOS)
├── calamares/settings.conf       # Configuração do Calamares
├── pkgbuilds/                    # PKGBUILDs locais (<nome>/PKGBUILD)
├── build.sh                      # Automação do build (executar como usuário)
├── test-qemu.sh                  # Teste da ISO em QEMU/KVM
└── README.md
```

## Requisitos

- Arch Linux ou distribuição baseada em Arch (testado em **CachyOS**).
- Conexão com internet (download de kernel, Plasma, Proton etc.).
- ~15 GB livres para o build + ~10 GB para a ISO/work.
- Um usuário normal com `sudo` (o `sudo` é usado **apenas** para instalar
  dependências do host).

Dependências do host (instaladas automaticamente pelo `build.sh`):
`archiso`, `mkinitcpio`, `base-devel`, `git`, `curl`, `wget`, `diffutils`,
`patch`, `bc`, `python`, `libnewt`, `squashfs-tools`, `libisoburn`, `mtools`,
`dosfstools`, `zstd`, além de bibliotecas X11.

## Compilação

> **Importante:** execute como **usuário normal**, nunca como root.
> O `makepkg` se recusa a rodar como root e o `mkarchiso` funciona *rootless*
> via user namespaces.

```bash
# 1. Clone o repositório
git clone https://github.com/seu-usuario/bc250-gaming-iso.git
cd bc250-gaming-iso

# 2. Gere a ISO (pede a senha do sudo uma vez para instalar deps)
./build.sh
```

O script:

1. instala as dependências do host via `sudo pacman`;
2. compila os pacotes AUR (`bc250-control-center-git`,
   `cyan-skillfish-governor-smu`) e os PKGBUILDs locais em `pkgbuilds/`;
3. monta um repositório local (`localrepo/`) usado **somente no build**;
4. chama o `mkarchiso` com um `pacman.conf` de build (`SigLevel = Never`);
5. grava a ISO em `out/`.

### Opções do `build.sh`

| Opção          | Efeito                                                        |
|----------------|---------------------------------------------------------------|
| `--skip-deps`  | Não instala dependências do host (usa as já presentes).       |
| `--clean`      | Remove `work/`, `out/` e `localrepo/` antes de começar.       |
| `--keep-work`  | Mantém o diretório `work/` do `mkarchiso` ao final.           |
| `--with-extra` | Tenta compilar também os PKGBUILDs experimentais.             |
| `--no-iso`     | Apenas compila os pacotes e prepara o repositório local.      |
| `-h, --help`   | Mostra a ajuda.                                               |

Exemplos:

```bash
./build.sh --skip-deps          # deps já instaladas
./build.sh --clean              # build do zero
./build.sh --no-iso             # só compilar pacotes
```

### Assinatura de pacotes

- **Build:** o `pacman.conf` do build usa `SigLevel = Never`.
- **Sistema Live:** usa `airootfs/etc/pacman.conf` com
  `SigLevel = Required DatabaseOptional`; o `pacman-init.service` executa
  `pacman-key --init` e `pacman-key --populate` no boot do Live.
- **Sistema instalado (offline):** o script `bc250-cleanup-target` recria o
  keyring no destino com `pacman-key --init` e
  `pacman-key --populate archlinux cachyos`; a instalação não precisa de
  internet.

## Teste em QEMU

```bash
# Instale o QEMU e o firmware UEFI (uma vez)
sudo pacman -S --needed qemu-full edk2-ovmf

# Rode a ISO mais recente em out/ (cria um disco de teste de 24G)
./test-qemu.sh

# Ou informe um caminho específico
./test-qemu.sh out/bc250-gaming-2026.11.09-x86_64.iso

# Use outro disco de teste
BC250_QEMU_DISK=/caminho/para/teste.qcow2 ./test-qemu.sh
```

O script usa **KVM** quando `/dev/kvm` está acessível (senão cai para TCG),
tenta UEFI via OVMF (senão SeaBIOS), usa 4 GB de RAM / 4 CPUs e anexa um disco
virtio de 24 GB para testar o instalador offline. Apague o arquivo do disco
(`.build/qemu/bc250-test.qcow2`) para começar do zero.

Para habilitar KVM, adicione seu usuário ao grupo `kvm`:

```bash
sudo usermod -aG kvm "$USER"
# faça logout/login para aplicar
```

## Ambiente Live

- Usuário: **`deck`**
- Senha: **`deck`**
- Login automático no SDDM (sessão Plasma) e no `tty1`.
- `sudo` sem senha para `deck` **apenas no Live** (regra em
  `/etc/sudoers.d/deck`).
- Atalho **“Instalar Agora!”** na área de trabalho e no menu de aplicativos.
- Aviso de boas-vindas (`bc250-welcome`) é iniciado junto com o KDE.
- Instalação **offline**: o Calamares copia o SquashFS do Live (sem internet).

## Observações sobre a BC-250

- O driver **nct6687** (sensores/fans) já é fornecido pelo pacote
  `linux-cachyos-bc250`; o `build.sh` **não** copia módulos DKMS do host.
- Os scripts de desbloqueio de CU/core **não são aplicados automaticamente**;
  eles ficam disponíveis em `/usr/bin` para execução manual e consciente.
- Os repositórios CachyOS (`cachyos-v3`, `cachyos-extra-v3`,
  `cachyos-core-v3`) são otimizados para x86-64-v3, suportado pela CPU Zen2
  da BC-250.
- A ISO **não** usa `cachyos-v4-mirrorlist`: Zen2 (Ariel/Oberon) não suporta
  AVX-512/x86-64-v4, e pacotes v4 causariam SIGILL.
- O `amdgpu` é carregado com `ip_block_mask=0xffffffff` via
  `/etc/modprobe.d/amdgpu.conf`.

## Créditos e Agradecimentos

Este projeto integra e empacota trabalhos da comunidade. Todos os créditos
aos autores originais:

### Kernel e performance
1. **linux-cachyos-bc250** — https://github.com/MastaG/linux-cachyos-bc250
   - Mantenedor: **MastaG**
   - Kernel CachyOS otimizado para a APU AMD BC-250 e repositório
     `bc250-cachyos`.
2. **bc250-gfx1013-fix** — https://github.com/DryhoppedIPA/bc250-gfx1013-fix
   - Mantenedor: **DryhoppedIPA**
   - Patches de kernel/Mesa para gfx1013 (referência/experimental).
3. **cyan-skillfish-governor** — https://github.com/filippor/cyan-skillfish-governor
   - Mantenedor: **filippor**
   - Governor Cyan Skillfish (modo SMU), empacotado como
     `cyan-skillfish-governor-smu`.
4. **bc250-cec / bc250-fixes / bc250-dual-audio / bc250-vcn-fw** —
   repositório `bc250-cachyos` (MastaG)
   - Mantenedor: **MastaG**
   - Correções e firmwares específicos da BC-250.

### Desbloqueios e tweaks de CPU/CU
5. **bc250-40cu-unlock** — https://github.com/duggasco/bc250-40cu-unlock
   - Mantenedor: **duggasco**
   - Scripts e patch de referência para reativar as 40 CUs.
6. **bc250-core-unlock** — https://github.com/rw-r-r-0644/bc250-core-unlock
   - Mantenedor: **rw-r-r-0644**
   - Reativa os 2 núcleos de CPU desabilitados.
7. **bc250-cu-live-manager** — https://github.com/WinnieLV/bc250-cu-live-manager
   - Mantenedor: **WinnieLV**
   - Gerenciador interativo de WGP/CU.
8. **bc250-efi-core-unlock** — https://github.com/Hexxeh/bc250-efi-core-unlock
   - Mantenedor: **Hexxeh**
   - Desbloqueio de núcleos via EFI (referência/experimental).
9. **bc250_smu_oc** — https://github.com/bc250-collective/bc250_smu_oc
   - Mantenedor: **bc250-collective**
   - Ferramentas de overclock via SMU (referência/experimental).

### Monitoramento, telemetria e hardware
10. **bc250-control-center** — https://github.com/movacx/bc250-control-center
    - Mantenedor: **movacx**
    - Central de monitoramento/ajuste/recovery, empacotada como
      `bc250-control-center-git`.
11. **BC250-Telemetry** — https://github.com/onlinermm/BC250-Telemetry
    - Mantenedor: **onlinermm**
    - Telemetria da BC-250 (referência/experimental).
12. **bc250-memory-temperature** — https://github.com/pan-Rijovich/bc250-memory-temperature
    - Mantenedor: **pan-Rijovich**
    - Temperatura de memória (referência/experimental).
13. **nct6687d** — https://github.com/Fred78290/nct6687d
    - Mantenedor: **Fred78290**
    - Driver Super I/O Nuvoton NCT6687D (já embutido no kernel
      `linux-cachyos-bc250`).

### Upscaling e gráficos
14. **bc250-fsr4** — https://github.com/dmorazasanchez/bc250-fsr4
    - Mantenedor: **dmorazasanchez**
    - FSR4 para a APU (referência/experimental).
15. **bc250-fsr4-fork** — https://github.com/daniel-h-0/bc250-fsr4-fork
    - Mantenedor: **daniel-h-0**
    - Fork do FSR4 (referência/experimental).

### Ferramentas de base
- **archiso** — https://gitlab.archlinux.org/archlinux/archiso
  - Ferramenta oficial de build de ISO do Arch Linux.
- **Calamares** — https://github.com/calamares/calamares
  - Instalador gráfico; configuração base do pacote `cachyos-calamares`.
- **CachyOS** — https://cachyos.org/
  - Repositórios otimizados, kernel e patches de performance.
- **Projeto BC-250** — integração, automação e empacotamento deste projeto.

## Licença

Este projeto está licenciado sob a licença **MIT**. Consulte os arquivos e
repositórios individuais para as licenças de cada componente de terceiros.

---

**Aviso:** projeto comunitário não oficial. Não há vínculo com a AMD, Sony ou
CachyOS. Use por sua conta e risco — desbloqueios de CU/core podem afetar
temperatura, consumo e estabilidade do hardware.
