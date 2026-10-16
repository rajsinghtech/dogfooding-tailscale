# IP rule: Route traffic to fd7a:115c:a1e0::/48 using custom table 52
ip -6 rule add to fd7a:115c:a1e0::/48 lookup 52 pref 1100

# IP rule: Route marked packets (0x40000) via table 52
ip -6 rule add fwmark 0x40000/0xff0000 lookup 52

# IP route: In table 52, send Tailscale ULA traffic via the Tailscale interface
ip -6 route add fd7a:115c:a1e0::/48 dev tailscale0 table 52

# ip6tables mangle PREROUTING: Mark incoming packets to Tailnet from pods
ip6tables -t mangle -A PREROUTING -d fd7a:115c:a1e0::/48 -j MARK --set-mark 0x40000

# ip6tables mangle OUTPUT: Mark host-originated packets to Tailnet
ip6tables -t mangle -A OUTPUT -d fd7a:115c:a1e0::/48 -j MARK --set-mark 0x40000

# ip6tables FORWARD: Allow pod-to-Tailnet forwarding through tailscale0
ip6tables -A FORWARD -s 2600:1f10:4cb9:e000::/56 -d fd7a:115c:a1e0::/48 -o tailscale0 -j ACCEPT

# ip6tables NAT POSTROUTING: NAT pod IPs to host's Tailscale IP for Tailnet (requires NAT support)
ip6tables -t nat -A POSTROUTING -s 2600:1f10:4cb9:e000::/56 -d fd7a:115c:a1e0::/48 -j MASQUERADE
