# systemd-notworkd

While working on a unit test that creates some virtual network interfaces and
then plays Ethernet ping-pong (or rather, the unidirectional variant) I noticed
that this test often failed, but not always. The symptom was that while the
sender sent Ethernet packets from the first MACVLAN, the receiver never received
them on the second MACVLAN. I made sure to wait for the MACVLANs to become
operational, but this didn't improve the situation.

Being thoroughly bugged I finally decided to give running the unit test in a
separate network namespace a try. And to my not so large surprise the same unit
test now worked flawlessly _all the time_.

Now there are two suspects that could be involved:
[NetworkManager](https://en.wikipedia.org/wiki/NetworkManager) and systemd's
[networkd](https://en.wikipedia.org/wiki/Systemd#networkd).

## NetworkManager

Ubuntu-based distributions in general define in
`/usr/lib/NetworkManager/conf.d/10-globally-managed-devices.conf` all network
interfaces to be unmanaged, except for those of type "wifi", "gsm", and "cdma":

```ini
[keyfile]
unmanaged-devices=*,except:type:wifi,except:type:gsm,except:type:cdma
```

Cross-checking the situation by adding an `unmanaged-devices` statement to
`/etc/NetworkManager/NetworkManager.conf` and listing the MACVLANs based on the
naming scheme used in the unit test didn't improve the situation in any way.

## Keeping `notworkd`’s Sticky Fingers Off

So I turned my interest to systemd's `networkd`, especially after I came across
some note saying that it at some time gained MACVLAN awareness. Oh bummer,
that's exactly what you don't want: `networkd`’s "awareness".

Now, `networkd` deals with three different units of configuration:
1. "networks" configuration in `*.network` files, especially IP configuration,
   et cetera.
2. creation of new virtual network interfaces via `*.netdev` configuration
   files. 
3. configuration of just the network interfaces (created by someone else,
   including plug-and-play) using `*.link` files – not to be confused with the
   "network" configuration.

It is the third case we need to deal with in this case: a unit test dynamically
creates virtual network interfaces. Unfortunately, in its default configuration,
`networkd` plays havoc with these unit test MACVLAN interfaces.

So, in order to tell `systemd-notworkd` to keep its sticky fingers of certain
MACVLAN network interfaces (those with names starting with `mcvl-`) used for
unit testing create the follwing file `/etc/systemd/network/00-notwork.link`:

```ini
[Match]
Kind=macvlan
OriginalName=mcvl-*

[Link]
Description="keep systemd's sticky fingers off test netdevs"
Unmanaged=yes
```

Make sure to execute

```bash
sudo systemctl restart systemd-networkd.service
```

in order to activate the updated configuration.
