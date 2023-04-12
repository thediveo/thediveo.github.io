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

## notworkd

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
`networkd` plays havoc with these unit test MACVLAN interfaces. But how exactly?

## Configuration Autopsy

But what actually happens and why is my unit test failing in such a strange
manner? How can `notworkd` trip up a test that sends Ethernet packets from one
netdev to a second netdev?

It took me some time to finally have the correct inspiration: what if `notworkd`
plays havoc with the MAC address(es)? A quickly added unit test expectation
(assertion) confirmed my inspiration...

```go
mac2 := Successful(netlink.LinkByIndex(macvlan2.Attrs().Index)).Attrs().HardwareAddr
// ...
By("systemd-notworkd check")
mac2now := Successful(
   netlink.LinkByIndex(macvlan2.Attrs().Index)).Attrs().HardwareAddr
Expect(mac2now).To(Equal(mac2),
   "systemd-notworkd trashed the netdev: original MAC %s, new MAC %s",
   mac2.String(), mac2now.String())
```

Just for completeness and as a good cross-check:

```ini
# /usr/lib/systemd/network/99-default.link
[Match]
OriginalName=*

[Link]
NamePolicy=keep kernel database onboard slot path
AlternativeNamesPolicy=database onboard slot path
MACAddressPolicy=persistent
```

Now, `MACAddressPolicy=persistent` [doesn't exactly
do](https://www.freedesktop.org/software/systemd/man/systemd.link.html#%5BLink%5D%20Section%20Options)
what you think it may do:

> If the hardware has a persistent MAC address, as most hardware should, and if
> it is used by the kernel, nothing is done. Otherwise, a new MAC address is
> generated which is guaranteed to be the same on every boot for the given
> machine and the given device, but which is otherwise random.

Guess what happens on a MACVLAN netdev that doesn't have a persistent MAC
address, but a random one? Smarty McPants Notworkd now replaces the random MAC
with another random MAC, albeit a "persistent" one.

Funnily, `MACAddressPolicy=random` doesn't replace the random MAC.

## Remedy

So, in order to tell `systemd-notworkd` to keep its sticky fingers of certain
MACVLAN network interfaces (those with names starting with `mcvl-`) used for
unit testing create the follwing file:

```ini
# /etc/systemd/network/00-notwork.link
[Match]
Kind=macvlan
OriginalName=mcvl-*

[Link]
Description="keep systemd's sticky fingers off test netdevs"
MACAddressPolicy=none
```

This updated configuration will be picked up automatically and applied to any
matching netdev afterwards. It won't affect existing matching netdevs though.
