# Synology enable M2 card

<a href="https://github.com/007revad/Synology_enable_M2_card/releases"><img src="https://img.shields.io/github/release/007revad/Synology_enable_M2_card.svg"></a>
<a href="https://hits.seeyoufarm.com"><img src="https://hits.seeyoufarm.com/api/count/incr/badge.svg?url=https%3A%2F%2Fgithub.com%2F007revad%2FSynology_enable_M2_card&count_bg=%2379C83D&title_bg=%23555555&icon=&icon_color=%23E7E7E7&title=hits&edge_flat=false"/></a>
[![](https://img.shields.io/static/v1?label=Sponsor&message=%E2%9D%A4&logo=GitHub&color=%23fe8e86)](https://github.com/sponsors/007revad)

### Description

Enable Synology M.2 PCIe cards in Synology NAS that don't officially support them

Allows using your E10M20-T1, M2D20 or M2D18 cards in Synology NAS models that aren't on their supported model list.

  - Enables E10M20-T1, M2D20 and M2D18 for DS1821+, DS1621+.
  - Enables M2D18 for DS1823xs+, DS2422+, RS2423+, RS2421+, RS2421RP+, RS2821RP+.
  - Enables M2D18 for RS822RP+, RS822+, RS1221RP+ and RS1221+ using DSM 7.1.1 and older.
  - Enables E10M20-T1, M2D20, M2D18 and M2D17 for other models  with a PCIe slot.

| Model | E10M20-T1 | M2D20 | M2D18 | M2D17 | Notes |
|-|-|-|-|-|-|
| DS1821+   | yes | yes | yes | | |
| DS1621+   | yes | yes | yes | | |
| DS1823xs+ |     |     | yes | | E10M20-T1	and M2D20 already enabled in DSM |
| DS2422+   |     |     | yes | | E10M20-T1	and M2D20 already enabled in DSM |
| RS2423+   |     |     | yes | | E10M20-T1	and M2D20 already enabled in DSM |
| RS2421+   |     |     | yes | | E10M20-T1	and M2D20 already enabled in DSM |
| RS2421RP+ |     |     | yes | | E10M20-T1	and M2D20 already enabled in DSM |
| RS2821RP+ |     |     | yes | | E10M20-T1	and M2D20 already enabled in DSM |
| RS822+    |     |     | yes | | M2D18 already enabled in DSM 7.2 |
| RS822RP+  |     |     | yes | | M2D18 already enabled in DSM 7.2 |
| RS1221+   |     |     | yes | | M2D18 already enabled in DSM 7.2 |
| RS1221RP+ |     |     | yes | | M2D18 already enabled in DSM 7.2 |
| others    | yes | yes | yes | yes | The NAS must have a PCIe slot |

<p align="center">Available options</p>
<p align="center"><img src="/images/help.png"></p>

<p align="center">Enabling all M.2 card models</p>
<p align="center"><img src="/images/edited.png"></p>

<p align="center">Checking the current M.2 card settings</p>
<p align="center"><img src="/images/check.png"></p>

<p align="center">E10M20-T1 already enabled</p>
<p align="center"><img src="/images/e10m20.png"></p>

<p align="center">All M.2 card models already enabled</p>
<p align="center"><img src="/images/all.png"></p>

<p align="center">Restoring the original M.2 card settings</p>
<p align="center"><img src="/images/restore.png"></p>
