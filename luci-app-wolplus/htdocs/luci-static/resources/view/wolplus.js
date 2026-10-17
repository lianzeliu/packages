'use strict';
'require form';
'require rpc';
'require ui';
'require uci';
'require view';
'require tools.widgets as widgets';

var callHostHints = rpc.declare({
	object: 'luci-rpc',
	method: 'getHostHints',
	expect: { '': {} }
});

var callSync = rpc.declare({
	object: 'luci.wolplus',
	method: 'sync',
	expect: { '': {} }
});

var callWake = rpc.declare({
	object: 'luci.wolplus',
	method: 'wake',
	params: [ 'iface', 'mac' ],
	expect: { '': {} }
});

function addHostHints(option, hosts) {
	L.sortedKeys(hosts).forEach(function(mac) {
		var hint = hosts[mac].name ||
			L.toArray(hosts[mac].ipaddrs || hosts[mac].ipv4)[0] ||
			L.toArray(hosts[mac].ip6addrs || hosts[mac].ipv6)[0];

		option.value(mac, hint ? '%s (%s)'.format(mac, hint) : mac);
	});

}

function normalizeCronExpression(value) {
	return String(value || '').trim().replace(/\s+/g, ' ');
}

function cronExpression(section_id) {
	var expression = uci.get('wolplus', section_id, 'cron');

	if (expression)
		return normalizeCronExpression(expression);

	return '%s %s %s %s %s'.format(
		uci.get('wolplus', section_id, 'minute') || '0',
		uci.get('wolplus', section_id, 'hour') || '0',
		uci.get('wolplus', section_id, 'day') || '*',
		uci.get('wolplus', section_id, 'month') || '*',
		uci.get('wolplus', section_id, 'weeks') || '*');
}

function validateCronField(field, minimum, maximum) {
	return field.split(',').every(function(item) {
		var parts = item.split('/');
		if (parts.length > 2 || !parts[0])
			return false;

		if (parts.length === 2) {
			var step = Number(parts[1]);
			if (!/^\d+$/.test(parts[1]) || step < 1 || step > maximum - minimum + 1)
				return false;
		}

		if (parts[0] === '*')
			return true;

		var range = parts[0].split('-');
		if (range.length > 2 || range.some(function(value) { return !/^\d+$/.test(value); }))
			return false;

		var start = Number(range[0]);
		var end = Number(range[range.length - 1]);
		return start >= minimum && end <= maximum && start <= end;
	});
}

function validateCronExpression(section_id, value) {
	var fields = normalizeCronExpression(value).split(' ');
	var limits = [ [ 0, 59 ], [ 0, 23 ], [ 1, 31 ], [ 1, 12 ], [ 0, 6 ] ];

	if (fields.length === limits.length && fields.every(function(field, index) {
		return validateCronField(field, limits[index][0], limits[index][1]);
	}))
		return true;

	return _('Expecting: %s').format(_('valid cron expression'));
}

function cronDescription() {
	return _('Minutes (0-59), hours (0-23), days (1-31), months (1-12), weekdays (0-6).') +
		'<br/>' +
		'<a target="_blank" rel="noreferrer noopener" href="https://www.toolbox365.cn/tools/cron/">' +
		_('Cron expression online generator') + '</a>';
}

function scheduleText(section_id) {
	if (uci.get('wolplus', section_id, 'scheduled') !== '1')
		return _('Disabled');

	return cronExpression(section_id);
}

return view.extend({
	load: function() {
		return Promise.all([
			L.resolveDefault(callHostHints(), {}),
			uci.load('wolplus')
		]);
	},

	render: function(data) {
		var hosts = data[0] || {};
		var m, s, o;
		var view = this;

		m = new form.Map('wolplus', _('WOL Plus'),
			_('Wake local network devices immediately or on an individual schedule. — AI Edition'));

		s = m.section(form.NamedSection, 'global', 'global', _('Global Settings'),
			_('Direct wake links let you wake a device with a single URL, without logging in to LuCI. Keep the token secret: anyone holding the link can wake devices.'));

		o = s.option(form.Value, 'token', _('Wake Token'));
		o.rmempty = true;
		o.placeholder = _('Leave empty to disable direct wake links');
		o.description = _('Used as the <code>?token=</code> suffix in direct wake links, e.g. <code>/cgi-bin/wolplus-wake?mac=AA:BB:CC:DD:EE:FF&token=…</code>');

		/* Use the form API (getOption / getUIElement / setValue) to fill
		   the token field. DOM lookups (getWidget does not exist, cbid /
		   name schemes differ) and DummyValue renderWidget overrides
		   proved unreliable. */
		o = s.option(form.Button, '_generate_token', _('Generate Token'));
		o.inputtitle = _('Generate');
		o.inputstyle = 'action';
		o.onclick = function(ev, section_id) {
			var tokenOpt = this.section.getOption('token');
			var elem = tokenOpt ? tokenOpt.getUIElement(section_id) : null;
			if (elem) {
				var bytes = new Uint8Array(16);
				crypto.getRandomValues(bytes);
				elem.setValue(Array.from(bytes).map(function(b) {
					return ('0' + b.toString(16)).slice(-2);
				}).join(''));
				if (elem.node) {
					elem.node.dispatchEvent(new Event('input', { bubbles: true }));
					elem.node.dispatchEvent(new Event('change', { bubbles: true }));
				}
			}
		};

		s = m.section(form.GridSection, 'macclient', _('Client Settings'));
		s.anonymous = true;
		s.addremove = true;
		s.sortable = true;
		s.tab('general', _('General Settings'));
		s.tab('schedule', _('Scheduled Wake'));

		o = s.taboption('general', form.Value, 'name', _('Name'));
		o.rmempty = false;

		o = s.taboption('general', form.Value, 'macaddr', _('MAC Address'));
		o.rmempty = false;
		o.datatype = 'macaddr';
		addHostHints(o, hosts);

		o = s.taboption('general', widgets.DeviceSelect, 'maceth', _('Network Interface'));
		o.rmempty = false;
		o.default = 'br-lan';
		o.noaliases = true;
		o.noinactive = true;

		o = s.taboption('schedule', form.Flag, 'scheduled', _('Scheduled Wake'));
		o.default = '0';
		o.rmempty = false;
		o.modalonly = true;

		o = s.taboption('schedule', form.DummyValue, '_schedule', _('Scheduled Wake'));
		o.modalonly = false;
		o.textvalue = scheduleText;

		o = s.taboption('schedule', form.Value, 'cron', _('Cron expression'), cronDescription());
		o.default = '0 0 * * *';
		o.placeholder = '0 0 * * *';
		o.rmempty = false;
		o.modalonly = true;
		o.depends('scheduled', '1');
		o.cfgvalue = function(section_id) {
			return cronExpression(section_id);
		};
		o.validate = validateCronExpression;
		o.write = function(section_id, value) {
			uci.set('wolplus', section_id, 'cron', normalizeCronExpression(value));
			[ 'minute', 'hour', 'day', 'month', 'weeks' ].forEach(function(name) {
				uci.unset('wolplus', section_id, name);
			});
		};

		s.renderRowActions = function(section_id) {
			var defaultButtons = form.GridSection.prototype.renderRowActions.call(this, section_id);
			var buttonContainer = defaultButtons.querySelector('div');
			var wakeButton = E('button', {
				'type': 'button',
				'class': 'btn cbi-button cbi-button-action',
				'click': ui.createHandlerFn(this, function() {
					return view.handleWakeup(section_id);
				})
			}, _('Wake'));

			var linkButton = E('button', {
				'type': 'button',
				'class': 'btn cbi-button cbi-button-action',
				'click': ui.createHandlerFn(this, function() {
					return view.handleCopyLink(section_id);
				})
			}, _('Copy Link'));

			if (buttonContainer) {
				var editButton = buttonContainer.querySelector('.cbi-button-edit');
				buttonContainer.insertBefore(wakeButton, editButton || buttonContainer.firstChild);
				buttonContainer.insertBefore(linkButton, editButton || buttonContainer.firstChild);
			}

			return defaultButtons;
		};

		return m.render();
	},

	handleWakeup: function(section_id) {
		var name = uci.get('wolplus', section_id, 'name') || section_id;
		var mac = uci.get('wolplus', section_id, 'macaddr');
		var iface = uci.get('wolplus', section_id, 'maceth') || 'br-lan';

		if (!mac) {
			ui.addNotification(null, E('p', _('Please save the client before waking it up.')), 'error');
			return Promise.resolve();
		}

		return callWake(iface, mac).then(function(res) {
			res = res || {};

			var output = (res.stdout || res.stderr || '').trim();
			var code = res.code;
			var message = output || _('Wake command completed with code %d.').format(code || 0);
			var level = (code == null || code === 0) ? 'info' : 'error';

			ui.addNotification(null, E('p', [
				_('Wake Host'), ': ', name, ' (', mac, ')',
				E('br'), message
			]), level);
		}).catch(function(err) {
			ui.addNotification(null, E('p', _('Wake command failed: %s.').format(err.message || err)), 'error');
		});
	},

	handleCopyLink: function(section_id) {
		var mac = uci.get('wolplus', section_id, 'macaddr');
		var token = uci.get('wolplus', 'global', 'token');

		if (!mac) {
			ui.addNotification(null, E('p', _('Please save the client before copying its wake link.')), 'error');
			return Promise.resolve();
		}

		if (!token) {
			ui.addNotification(null, E('p', _('Please set a wake token in Global Settings first.')), 'error');
			return Promise.resolve();
		}

		var url = window.location.origin + '/cgi-bin/wolplus-wake?mac=' +
			encodeURIComponent(mac) + '&token=' + encodeURIComponent(token);

		var done = function() {
			ui.addNotification(null, E('p', _('Copied successfully')), 'info');
		};

		var failed = function() {
			ui.addNotification(null, E('p', _('Failed to copy the wake link.')), 'error');
		};

		/* navigator.clipboard needs a secure context (HTTPS/localhost);
		   plain-HTTP LAN LuCI has none, so fall back to execCommand
		   which works everywhere. Copy directly, no prompt dialog. */
		var copyLegacy = function() {
			var ta = document.createElement('textarea');
			ta.value = url;
			ta.style.position = 'fixed';
			ta.style.opacity = '0';
			document.body.appendChild(ta);
			ta.focus();
			ta.select();
			ta.setSelectionRange(0, ta.value.length);
			var ok = false;
			try {
				ok = document.execCommand('copy');
			} catch (e) {
				ok = false;
			}
			document.body.removeChild(ta);
			if (ok)
				done();
			else
				failed();
		};

		if (navigator.clipboard && navigator.clipboard.writeText) {
			return navigator.clipboard.writeText(url).then(done).catch(copyLegacy);
		}

		copyLegacy();
		return Promise.resolve();
	},

	handleSaveApply: function(ev, mode) {
		return this.handleSave(ev).then(function() {
			return ui.changes.apply(mode == '0');
		}).then(function() {
			return L.resolveDefault(callSync(), null).then(function(result) {
				if (!result || !result.success)
					ui.addNotification(null, E('p', _('Failed to update scheduled wake tasks.')), 'error');
			});
		});
	}
});
