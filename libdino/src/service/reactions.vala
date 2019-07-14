using Gee;
using Qlite;

using Xmpp;
using Dino.Entities;

namespace Dino {
public class Reactions : StreamInteractionModule, Object {
    public static ModuleIdentity<Reactions> IDENTITY = new ModuleIdentity<Reactions>("reactions");
    public string id { get { return IDENTITY.id; } }

    public signal void reaction_added(Account account, Message message, Jid jid, string reaction);
    public signal void reaction_removed(Account account, Message message, Jid jid, string reaction);

    private StreamInteractor stream_interactor;
    private Database db;

    public static void start(StreamInteractor stream_interactor, Database database) {
        Reactions m = new Reactions(stream_interactor, database);
        stream_interactor.add_module(m);
    }

    private Reactions(StreamInteractor stream_interactor, Database database) {
        this.stream_interactor = stream_interactor;
        this.db = database;
        stream_interactor.account_added.connect(on_account_added);
    }

    public void send_reactions(Account account, Message message, Gee.List<string> reactions) {
        Conversation? conversation = stream_interactor.get_module(ConversationManager.IDENTITY).get_conversation_for_message(message); // TODO use conversation
        XmppStream stream = stream_interactor.get_stream(account);
        stream.get_module(Xmpp.Xep.Reactions.Module.IDENTITY).send_reaction(stream, conversation.counterpart, message.unique_id ?? message.stanza_id, reactions);
        save_reaction(account, account.bare_jid, message, reactions);
    }

    public void add_reaction(Account account, Message message, string reaction) {
        Gee.List<string> reactions = get_own_reactions(account, message);
        if (!reactions.contains(reaction)) {
            reactions.add(reaction);
        }
        send_reactions(account, message, reactions);
        reaction_added(account, message, account.bare_jid, reaction);
    }

    public void remove_reaction(Account account, Message message, string reaction) {
        Gee.List<string> reactions = get_own_reactions(account, message);
        reactions.remove(reaction);
        send_reactions(account, message, reactions);
        reaction_removed(account, message, account.bare_jid, reaction);
    }

    public Gee.List<string> get_own_reactions(Account account, Message message) {
        return get_user_reactions(account, message, account.bare_jid);
    }

    public Gee.List<string> get_user_reactions(Account account, Message message, Jid jid) {
        QueryBuilder select = db.reaction.select()
                .with(db.reaction.account_id, "=", account.id)
                .with(db.reaction.message_id, "=", message.id)
                .with(db.reaction.jid_id, "=", db.get_jid_id(jid));

        Gee.List<string> ret = new ArrayList<string>();
        foreach (Row row in select) {
            string emoji_str = row[db.reaction.emojis];
            foreach (string emoji in emoji_str.split(",")) {
                if (emoji.length != 0)
                ret.add(emoji);
            }
            break;
        }
        return ret;
    }

    public HashMap<string, Gee.List<Jid>> get_message_reactions(Account account, Message message) {
        QueryBuilder select = db.reaction.select()
                .with(db.reaction.account_id, "=", account.id)
                .with(db.reaction.message_id, "=", message.id);

        HashMap<string, Gee.List<Jid>> ret = new HashMap<string, Gee.List<Jid>>();
        foreach (Row row in select) {
            string emoji_str = row[db.reaction.emojis];
            Jid jid = Jid.parse(db.get_jid_by_id(row[db.reaction.jid_id]));

            foreach (string emoji in emoji_str.split(",")) {
                if (!ret.contains(emoji)) {
                    ret[emoji] = new ArrayList<Jid>(Jid.equals_func);
                }
                ret.get(emoji).add(jid);
            }
        }
        return ret;
    }

    private void on_account_added(Account account) {
        stream_interactor.module_manager.get_module(account, Xmpp.Xep.Reactions.Module.IDENTITY).received_reactions.connect((stream, jid, message_unique_id, reactions) => {
            Message? message = stream_interactor.get_module(MessageStorage.IDENTITY).get_message_by_unique_id(account, message_unique_id);
            if (message == null) {
                Conversation conversation = stream_interactor.get_module(MessageStorage.IDENTITY).get_conversation_for_stanza_id(account, message_unique_id);
                print(conversation.counterpart.bare_jid.to_string() + " << conversation !!! \n");
                message = stream_interactor.get_module(MessageStorage.IDENTITY).get_message_by_stanza_id(message_unique_id, conversation);
            }
            print(@"React to $((message == null) ? "null" : message.id.to_string()) in account $(account.id)\n");
            if (message == null) return;

            Gee.List<string> current_reactions = get_user_reactions(account, message, jid);
            var matching_reactions = new ArrayList<string>();
            for (int i = 0; i < current_reactions.size; i++) {
                if (reactions.contains(current_reactions[i])) {
                    matching_reactions.add(current_reactions[i]);
                }
            }

            foreach (string current_reaction in current_reactions) {
                if (!matching_reactions.contains(current_reaction)) {
                    reaction_removed(account, message, jid, current_reaction);
                }
            }

            foreach (string reaction in reactions) {
                if (!matching_reactions.contains(reaction)) {
                    reaction_added(account, message, jid, reaction);
                }
            }

            save_reaction(account, jid, message, reactions);
        });
    }

    private void save_reaction(Account account, Jid jid, Message message, Gee.List<string> reactions) {
        int jid_id = db.get_jid_id(jid);

        var emoji_builder = new StringBuilder();
        for (int i = 0; i < reactions.size; i++) {
            if (i != 0) emoji_builder.append(",");
            emoji_builder.append(reactions[i]);
        }
        print(@"Save reaction from $jid for account $(account.id) about $(message.unique_id): $(emoji_builder.str)\n");

        db.reaction.upsert()
                .value(db.reaction.account_id, account.id, true)
                .value(db.reaction.message_id, message.id, true)
                .value(db.reaction.jid_id, jid_id, true)
                .value(db.reaction.emojis, emoji_builder.str, false)
                .perform();
    }
}

}
