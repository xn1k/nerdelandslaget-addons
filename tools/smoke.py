"""Offline smoke test for the Nerdelandslaget suite (core + Dungeon Finder).

    python -I tools/smoke.py <pylib dir with lupa>

Loads both addons in TOC order on tools/wowmock.lua, then plays a session: login, joining the
hidden channel, opening every tab, the demo, hearing listings, listing yourself, asking to
join, leading a group with an applicant, declining, a party forming, and the options pages.
Exits 1 on any Lua error or failed check.
"""
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, sys.argv[1])
from lupa import lua51  # noqa: E402

lua = lua51.LuaRuntime(unpack_returned_tuples=True)
lua.execute(open(os.path.join(ROOT, "tools", "wowmock.lua"), encoding="utf-8").read())
G = lua.globals()
problems = []


def toc_files(addon):
    path = os.path.join(ROOT, addon, addon + ".toc")
    lines = open(path, encoding="utf-8").read().splitlines()
    return [l.strip().replace("\\", "/") for l in lines if l.strip() and not l.startswith("#")]


def load(addon):
    ns = lua.table()
    for f in toc_files(addon):
        src = open(os.path.join(ROOT, addon, f), encoding="utf-8").read()
        chunk = lua.eval("function(src, name) local f, err = loadstring(src, '@' .. name) return f, err end")
        fn, err = chunk(src, addon + "/" + f)
        if err:
            problems.append("syntax: " + err)
            continue
        try:
            fn(addon, ns)
        except lua51.LuaError as e:
            problems.append(f"load {addon}/{f}: {e}")
    return ns


def run(code, label):
    try:
        return lua.execute(code)
    except lua51.LuaError as e:
        problems.append(f"{label}: {e}")


def check(cond, label):
    if not cond:
        problems.append("check failed: " + label)


def sent(prefix="NLLFG1"):
    out = []
    for i in range(1, len(G.mock.sent) + 1):
        m = G.mock.sent[i]
        if m.prefix == prefix:
            out.append((m.text, m.dist, m.target))
    return out


def clear_sent():
    lua.execute("wipe(mock.sent)")


state = {}


def scenario():
    global core, lfg, L
    core = load("Nerdelandslaget")
    lfg = load("Nerdelandslaget_LFG")
    G.lfgns = lfg
    NL = G.Nerdelandslaget

    run("mock.fire('ADDON_LOADED', 'Nerdelandslaget') mock.fire('ADDON_LOADED', 'Nerdelandslaget_LFG')", "addon loaded")
    run("mock.fire('PLAYER_LOGIN') mock.fire('PLAYER_ENTERING_WORLD', true, false)", "login")
    run("mock.advance(12)", "join channel")
    check(G.mock.channelJoined, "joined the hidden channel")
    q = [t for t in sent() if t[0].startswith("Q;")]
    check(q and q[0][1] == "CHANNEL", f"query sent on the channel: {q}")

    # open the window, every tab, demo
    run("SlashCmdList.NERDELANDSLAGET('')", "/nl")
    win = G.NerdelandslagetLFGFrame
    check(win is not None and win._shown, "window opened")
    run("for i = 1, 3 do lfgns.Win.Open(i) end lfgns.Win.Open(1)", "tabs")
    run("SlashCmdList.NERDELANDSLAGET('lfg demo')", "demo")
    L = lfg.LFG
    check(len(list(L.players.items())) == 8 and len(list(L.groups.items())) == 4, "demo listings")
    run("lfgns.Win.Open(1) lfgns.LFG.db.browseKind = 'players' lfgns.Win.Refresh() lfgns.LFG.db.onlyFits = true lfgns.Win.Refresh()", "browse players")
    run("SlashCmdList.NERDELANDSLAGET('lfg demo')", "demo off")
    check(len(list(L.players.items())) == 0, "demo cleared")

    # hearing listings from others
    run("""
    mock.fire('CHAT_MSG_ADDON', 'NLLFG1', 'P;1;1;30;TD;5;13,14;SM pls', 'CHANNEL', 'Tanky-Firemaw')
    mock.fire('CHAT_MSG_ADDON', 'NLLFG1', 'G;2;9;33;D;30;38;2;13,14;5.32.H,1.34.T;SM GY then Lib', 'CHANNEL', 'Lockie')
    mock.fire('CHAT_MSG_ADDON', 'NLLFG1', 'P;3;1;30;TD;5;13;bad guild', 'CHANNEL', 'Outsider')
    mock.fire('CHAT_MSG_ADDON', 'NLLFG1', 'P;1;1;30;TD;5;13;secret', 'CHANNEL', { __secret = true })
    """, "hear listings")
    check(L.players["Tanky-Firemaw"] is not None, "player listing heard")
    check(L.players["Outsider-Firemaw"] is None, "outside guild ignored")
    g = L.groups["Lockie-Firemaw"]
    check(g is not None and g["min"] == 30 and g["max"] == 38, "group listing heard with range")
    needs = lua.eval("function() local n, open = lfgns.LFG.Needs('D', lfgns.LFG.groups['Lockie-Firemaw'].members) return n.T, n.H, n.D, open end")()
    check(tuple(needs) == (0, 0, 2, 2), f"group needs 2 damage: {needs}")
    run("lfgns.Win.Open(1) lfgns.LFG.db.browseKind = 'groups' lfgns.LFG.db.onlyFits = false lfgns.Win.Refresh()", "browse groups")

    # list myself
    clear_sent()
    run("""
    local c = lfgns.LFG.char
    c.roles = { H = true, D = true }
    c.dungeons = { [13] = true, [14] = true }
    c.comment = 'heals; all | night'
    lfgns.LFG.ListSelf()
    mock.advance(1)
    """, "list self")
    p = [t for t in sent() if t[0].startswith("P;")]
    check(p and p[0][0].startswith("P;2;5;32;HD;0;13,14;heals all night"), f"P line: {p}")
    fits = lua.eval("function() return (lfgns.LFG.GroupFitsMe(lfgns.LFG.groups['Lockie-Firemaw'])) end")()
    check(fits, "Lockie's group fits me")

    # a query makes listed players answer
    clear_sent()
    run("mock.fire('CHAT_MSG_ADDON', 'NLLFG1', 'Q;0.2.0', 'CHANNEL', 'Newbie') mock.advance(5)", "query answer")
    check(any(t[0].startswith("P;") for t in sent()), "answered a query")
    check(L.newerVersion == "0.2.0", "noticed a newer version")

    # ask to join; leader declines
    clear_sent()
    run("lfgns.LFG.Apply('Lockie-Firemaw') mock.advance(1)", "apply")
    a = [t for t in sent() if t[0].startswith("A;")]
    check(a and a[0][1] == "WHISPER" and a[0][2] == "Lockie-Firemaw", f"apply whisper: {a}")
    run("mock.fire('CHAT_MSG_ADDON', 'NLLFG1', 'N;declined', 'WHISPER', 'Lockie')", "declined")
    check(L.applied["Lockie-Firemaw"].declined == "declined", "decline recorded")

    # delist and lead a group
    clear_sent()
    run("""
    lfgns.LFG.DelistSelf(true)
    local g = lfgns.LFG.char.group
    g.role = 'H'
    g.dungeons = { [16] = true, [18] = true }
    g.manualLevels = false
    g.min, g.max = 0, 0
    lfgns.Win.Open(3)
    lfgns.LFG.ListGroup()
    mock.advance(1)
    """, "list group")
    gl = [t for t in sent() if t[0].startswith("G;")]
    check(gl and gl[0][0].startswith("G;2;5;32;H;36;46;0;16,18;;"), f"G line: {gl}")
    check(any(t[0] == "X;P" for t in sent()), "solo listing withdrawn")

    run("mock.fire('CHAT_MSG_ADDON', 'NLLFG1', 'A;1;38;T;can tank', 'WHISPER', 'Shieldy')", "applicant")
    check(L.applicants["Shieldy-Firemaw"] is not None, "applicant listed")
    run("lfgns.Win.Open(3)", "group tab with applicant")
    clear_sent()
    run("lfgns.LFG.Decline('Shieldy-Firemaw') mock.advance(1)", "decline")
    check(any(t[0] == "N;declined" and t[2] == "Shieldy-Firemaw" for t in sent()), "decline whisper")
    run("mock.fire('CHAT_MSG_ADDON', 'NLLFG1', 'A;1;38;T;again', 'WHISPER', 'Shieldy')", "applicant again")
    run("lfgns.LFG.InviteApplicant('Shieldy-Firemaw')", "invite")
    check(any(m.get("kind") == "INVITE" for m in [dict(G.mock.sent[i].items()) for i in range(1, len(G.mock.sent) + 1)]), "invite sent")

    # they join: the party forms, roles flow, the group fills and delists
    clear_sent()
    run("""
    mock.party = { { name = 'Shieldy', class = 'WARRIOR', classID = 1, level = 38 } }
    mock.fire('GROUP_ROSTER_UPDATE')
    mock.advance(2)
    mock.fire('CHAT_MSG_ADDON', 'NLLFG1', 'R;T', 'PARTY', 'Shieldy')
    mock.advance(2)
    lfgns.Win.Open(3)
    """, "party forms")
    check(L.applicants["Shieldy-Firemaw"] is None, "applicant cleared on join")
    gl = [t for t in sent() if t[0].startswith("G;")]
    check(gl and ";1.38.T;" in gl[-1][0], f"member with role in G line: {gl[-1:] if gl else gl}")
    run("""
    mock.party = {
      { name = 'Shieldy', class = 'WARRIOR', classID = 1, level = 38 },
      { name = 'A', class = 'MAGE', classID = 8, level = 37 },
      { name = 'B', class = 'ROGUE', classID = 4, level = 39 },
      { name = 'C', class = 'HUNTER', classID = 3, level = 40 },
    }
    mock.fire('GROUP_ROSTER_UPDATE')
    mock.advance(2)
    """, "group fills")
    check(not L.char.group.listed, "full group delisted")

    # not in the guilds: locked
    run("mock.player.guild = 'Some Other Guild' mock.party = {} lfgns.Win.Open(2)", "other guild")
    check(not lua.eval("lfgns.LFG.Allowed()"), "locked outside the guilds")
    run("mock.player.guild = 'Nerdelandslaget'", "guild back")

    # options, menus, minimap button, probe, slash
    run("NL = Nerdelandslaget NL.OpenOptions() mock.subpage:Show()", "options")
    run("NerdelandslagetMapButton:Fire('OnEnter') NerdelandslagetMapButton:Fire('OnClick', 'RightButton') NerdelandslagetMapButton:Fire('OnClick', 'LeftButton')", "map button")
    run("SlashCmdList.NERDELANDSLAGET('probe') SlashCmdList.NERDELANDSLAGET('help') Nerdelandslaget_OnAddonCompartmentClick(nil, 'LeftButton')", "slash")
    run("mock.advance(400)", "expiry and heartbeats")
    check(len(list(L.players.items())) == 0, "old listings expired")



try:
    scenario()
except Exception as e:  # a crash mid-scenario still reports what came before
    problems.append(f"scenario stopped: {e}")

for i in range(1, len(G.mock.errors) + 1):
    problems.append("lua error: " + G.mock.errors[i])
log = (G.Nerdelandslaget and G.Nerdelandslaget.db and G.Nerdelandslaget.db.log) or lua.table()
for i in range(1, len(log) + 1):
    if "error" in log[i] or "failed" in log[i]:
        problems.append("log: " + log[i])

print("problems:", problems if problems else "none")
sys.exit(1 if problems else 0)
