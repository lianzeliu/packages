#!/usr/bin/awk

function inInterfaces(host) {
	return(interfaces ~ "(^| )" host "($| )")
}

function newRule(arp_ip) {
	# nft 版：给新主机在 RRDIPT_FORWARD 里加 -s / -d 两条计数规则。
	# 正常情况下不会重复调用（已有规则的主机在计数解析里已经从
	# hosts 里删掉），但 nft 允许重复规则、重复了会算两遍，所以
	# 这里仍按本轮的 nft dump（nftRaw，由 wrtbwmon 传入）查一遍再加。
	# nftRaw 为空（比如只读 DB 的那次调用）时不查，直接加。
	if (nftRaw != "") {
		system("grep -Fq '" nftAddr " saddr " arp_ip " ' " nftRaw " 2>/dev/null || nft add rule " nftFam " wrtbwmon RRDIPT_FORWARD " nftAddr " saddr " arp_ip " counter return 2>/dev/null")
		system("grep -Fq '" nftAddr " daddr " arp_ip " ' " nftRaw " 2>/dev/null || nft add rule " nftFam " wrtbwmon RRDIPT_FORWARD " nftAddr " daddr " arp_ip " counter return 2>/dev/null")
	} else {
		system("nft add rule " nftFam " wrtbwmon RRDIPT_FORWARD " nftAddr " saddr " arp_ip " counter return 2>/dev/null")
		system("nft add rule " nftFam " wrtbwmon RRDIPT_FORWARD " nftAddr " daddr " arp_ip " counter return 2>/dev/null")
	}
}

# 注意：原来这里的 delRule 在 nft 版里删掉了。nft 不能按匹配条件删
# 规则，只能按 handle 删，awk 里拿不到可靠的 handle；过期规则改由
# wrtbwmon 的 pruneNftRules() 在本轮结束后按 handle 统一清。

function total(i) {
	return(bw[i "/in"] + bw[i "/out"])
}

BEGIN {
	# 9 字段格式不变：wrtbwmon 先把 nft dump 转成和原来 iptables
	# -nvxL 一样的行再喂进来，所以下面计数解析一行都不用改。
	iptNF	= 9
	if (ipv6) {
		nftFam	= "ip6"
		nftAddr	= "ip6"
	} else {
		nftFam	= "ip"
		nftAddr	= "ip"
	}
}

/^#/ { # get DB filename
	FS	= ","
	dbFile	= FILENAME
	next
}

# data from database; first file
ARGIND==1 { #!@todo this doesn't help if the DB file is empty.
	lb=$1

	if (lb !~ "^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$") next

	if (!(lb in mac)) {
		mac[lb]		= $1
		ip[lb]		= $2
		inter[lb]	= $3
		speed[lb "/in"]	= 0
		speed[lb "/out"]= 0
		bw[lb "/in"]	= $6
		bw[lb "/out"]	= $7
		firstDate[lb]	= $9
		lastDate[lb]	= $10
		ignore[lb]	= 1
	} else {
		if ($9 < firstDate[lb])
			firstDate[lb]	= $9
		if ($10 > lastDate[lb]) {
			ip[lb]		= $2
			inter[lb]	= $3
			lastDate[lb]	= $10
		}
		bw[lb "/in"]	+= $6
		bw[lb "/out"]	+= $7
		ignore[lb]	= 0
	}
	next
}

# not triggered on the first file
FNR==1 {
	FS=" "
	if(ARGIND == 2) next
}

# arp: ip hw flags hw_addr mask device
ARGIND==2 {
	#!@todo regex match IPs and MACs for sanity
	if (ipv6) {
		statFlag = ($6 != "FAILED" && $6 != "INCOMPLETE" && substr($1,1,1) != "f" && substr($1,1,1) != "d")
		macAddr	= $5
		hwIF	= $3
	} else {
		statFlag= ($3 != "0x0")
		macAddr	= $4
		hwIF	= $6
	}

	lb=$1
	if (hwIF != wanIF && statFlag && macAddr ~ "^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$") {
		hosts[lb]		= 1
		arp_mac[lb]		= macAddr
		arp_ip[lb]		= $1
		arp_inter[lb]		= hwIF
		arp_bw[lb "/in"]	= 0
		arp_bw[lb "/out"]	= 0
		arp_firstDate[lb]	= systime()
		arp_lastDate[lb]	= arp_firstDate[lb]
		arp_ignore[lb]		= 1
	}
	next
}

#!@todo could use mangle chain totals or tailing "unnact" rules to
# account for data for new hosts from their first presence on the
# network to rule creation. The "unnact" rules would have to be
# maintained at the end of the list, and new rules would be inserted
# at the top.
ARGIND==3 && NF==iptNF && $1!="pkts" { # nft 转成的 9 字段增量行，格式同原来 iptables -nvxL
	if (ipv6) {
		lfn = 6
		tag = "::/0"
	} else {
		lfn = 6
		tag = "0.0.0.0/0"
	}

	if ($(lfn) != "*") {
		m = $(lfn)
		n = m "/in"
	} else if ($(++lfn) != "*") {
		m = $(lfn)
		n = m "/out"
	} else if ($(++lfn) != tag) {
		m = $(lfn)
		n = m "/out"
	} else { # $(++lfn) != tag
		m = $(++lfn)
		n = m "/in"
	}

	if (mode == "diff" || mode == "noUpdate") print n, $2
	if (mode != "noUpdate") {
		if (inInterfaces(m)) { # if label is an interface
			if (!(m in arp_mac)) {
				cmd = "cat /sys/class/net/" m "/address"
				cmd | getline arp_mac[m]
				close(cmd)

				if (length(arp_mac[m]) == 0) arp_mac[m] = "00:00:00:00:00:00"

				arp_ip[m]		= "NA"
				arp_inter[m] 		= m
				arp_bw[m "/in"]		= 0
				arp_bw[m "/out"]	= 0
				arp_firstDate[m]	= systime()
				arp_lastDate[m]		= arp_firstDate[m]
				arp_ignore[lb]		= 1
			}
		} else {
			if (!(m in arp_mac)) hosts[m] = 0
			else delete hosts[m]
		}

		if ($2 > 0) {
			arp_bw[n]	= $2
			arp_lastDate[m]	= systime()
			arp_ignore[m]	= 0
		}
	}
}

END {
	if (mode == "noUpdate") exit

	for (i in arp_ip) {
		lb = arp_mac[i]
		if (!arp_ignore[i] || !(lb in mac)) {
			ignore[lb]	= 0

			if (lb in mac) {
				bw[lb "/in"]	+= arp_bw[i "/in"]
				bw[lb "/out"]	+= arp_bw[i "/out"]
				lastDate[lb]	= arp_lastDate[i]
			} else {
				bw[lb "/in"]	= arp_bw[i "/in"]
				bw[lb "/out"]	= arp_bw[i "/out"]
				firstDate[lb]	= arp_firstDate[i]
				lastDate[lb]	= arp_lastDate[i]
			}
			mac[lb]		= arp_mac[i]
			ip[lb]		= arp_ip[i]
			inter[lb]	= arp_inter[i]

			if (interval != 0) {
				speed[lb "/in"]	= int(arp_bw[i "/in"] / interval)
				speed[lb "/out"]= int(arp_bw[i "/out"] / interval)
			}
		}
	}

	close(dbFile)
	for (i in mac) {
		if (!ignore[i]) {
			print "#mac,ip,iface,speed_in,speed_out,in,out,total,first_date,last_date" > dbFile
			OFS=","
			for (i in mac)
				print mac[i], ip[i], inter[i], speed[i "/in"], speed[i "/out"], bw[i "/in"], bw[i "/out"], total(i), firstDate[i], lastDate[i] > dbFile
			close(dbFile)
			break
		}
	}

	# for hosts without rules: 只建新规则。过期规则不在这里删，
	# 由 wrtbwmon 的 pruneNftRules() 按 handle 清（见上面注释）。
	for (i in hosts)
		if (hosts[i]) newRule(i)
}
