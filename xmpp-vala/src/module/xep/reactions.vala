using Gee;

namespace Xmpp.Xep.Reactions {

private const string NS_URI = "urn:xmpp:reactions:0";

public class Module : XmppStreamModule {
    public static ModuleIdentity<Module> IDENTITY = new ModuleIdentity<Module>(NS_URI, "reactions");

    public signal void received_reactions(XmppStream stream, Jid jid, string message_unique_id, Gee.List<string> reactions);

    private ReceivedPipelineListener received_pipeline_listener = new ReceivedPipelineListener();

    public void send_reaction(XmppStream stream, Jid jid, string message_unique_id, Gee.List<string> reactions) {
        StanzaNode reactions_node = new StanzaNode.build("reactions", NS_URI).add_self_xmlns();
        reactions_node.put_attribute("to", message_unique_id);
        foreach (string reaction in reactions) {
            StanzaNode reaction_node = new StanzaNode.build("reaction", NS_URI);
            reaction_node.put_node(new StanzaNode.text(reaction));
            reactions_node.put_node(reaction_node);
        }

        MessageStanza message = new MessageStanza();
        message.to = jid;
        message.type_ = MessageStanza.TYPE_CHAT;
        message.stanza.put_node(reactions_node);

        stream.get_module(MessageModule.IDENTITY).send_message(stream, message);
    }

    public override void attach(XmppStream stream) {
        // TODO add entity capability
        stream.get_module(MessageModule.IDENTITY).received_pipeline.connect(received_pipeline_listener);
    }

    public override void detach(XmppStream stream) { }

    public override string get_ns() { return NS_URI; }
    public override string get_id() { return IDENTITY.id; }
}

public class ReceivedPipelineListener : StanzaListener<MessageStanza> {

    private const string[] after_actions_const = {"EXTRACT_MESSAGE_2"};

    public override string action_group { get { return ""; } }
    public override string[] after_actions { get { return after_actions_const; } }

    public override async bool run(XmppStream stream, MessageStanza message) {

        StanzaNode? reactions_node = message.stanza.get_subnode("reactions", NS_URI);
        if (reactions_node == null) return false;

        string? to_attribute = reactions_node.get_attribute("to");
        if (to_attribute == null) return false;

        Gee.List<string> reactions = new ArrayList<string>();
        foreach (StanzaNode reaction_node in reactions_node.get_subnodes("reaction", NS_URI)) {
            string? reaction = reaction_node.get_string_content();
            if (reaction == null) return false;

            if (!reactions.contains(reaction)) {
                reactions.add(reaction);
            }
        }
        print(@"$(stream.get_flag(Bind.Flag.IDENTITY).my_jid.bare_jid) $(message.to)\n");
        stream.get_module(Module.IDENTITY).received_reactions(stream, message.from, to_attribute, reactions);

        return false;
    }
}

}
