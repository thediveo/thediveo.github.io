---
title: "Publishing Ports (Explicitly) on Host-Local Networks"
shorttitle: "Publishing Ports @127.0.0.1"
description: "when 127.0.0.1 isn't as local as you wanted it to be."
---

# Publishing Ports (Explicitly) on Host-Internal Networks

One (potentially nasty) surprise in Docker's container networking has been all
the time that publishing a service port on `127.0.0.1` would not exactly do what
you might expect it to do. At least, Docker's networking documentation has for
some time a warning in its [Published
ports](https://docs.docker.com/engine/network/#published-ports) section:

> [!QUOTE]
>
> ⚠ Warning
>
> Hosts within the same L2 segment (for example, hosts connected to the same
> network switch) can reach ports published to localhost. For more information,
> see [moby/moby#45610](https://github.com/moby/moby/issues/45610)

To me, this always has been a sore sight, as it needed some other mitigation
mechanism, be it micro-segmentation, `firewalld` (the ~~useless~~ uncomplicated
firewall [ufw](https://en.wikipedia.org/wiki/Uncomplicated_Firewall) needs
manual intervention), or some heavy-handed `INPUT` default `DROP` policy.

But: finally, _finally_, [PR#48721](https://github.com/moby/moby/pull/48721) is
[scheduled for the release of Docker
v28.0](https://github.com/moby/moby/issues/45610#issuecomment-2583341455). This
PR adds the "missing" iptables (sic!) rules to filter on the input interface for
NAT port mappings.
