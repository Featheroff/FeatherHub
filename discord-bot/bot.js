require('dotenv').config();
const {
    Client, GatewayIntentBits, EmbedBuilder, ActionRowBuilder, ButtonBuilder, ButtonStyle,
    ChannelType, PermissionFlagsBits, Events, Partials
} = require('discord.js');

// ════════════════════════════════════════════════════════════════
// CONFIG
// ════════════════════════════════════════════════════════════════
const CONFIG = {
    token: process.env.BOT_TOKEN,
    guildId: process.env.GUILD_ID,
    roles: {
        verified: process.env.VERIFIED_ROLE_ID,
        support: process.env.SUPPORT_ROLE_ID,
    },
    channels: {
        verify: process.env.VERIFY_CHANNEL_ID,
        ban: process.env.BAN_CHANNEL_ID,
        ticketCategory: process.env.TICKET_CATEGORY_ID,
        log: process.env.LOG_CHANNEL_ID,
    },
    keyWorker: process.env.KEY_WORKER_URL || 'https://featherhub-keys.xyz-206.workers.dev',
};

// ════════════════════════════════════════════════════════════════
// I18N
// ════════════════════════════════════════════════════════════════
const T = {
    en: {
        verify_title: 'Verify yourself',
        verify_desc: 'Click the button below to get access to the server.',
        verify_button: 'Verify',
        verified: 'You are now verified! Welcome to FeatherHub.',
        already_verified: 'You are already verified.',
        ban_warning: 'This channel is read-only. Writing here results in an instant ban.',
        ban_log: 'User {user} ({id}) was banned for writing in #{channel}.',
        ban_reason: 'Writing in a read-only channel',
        status_title: 'FeatherHub Key System Status',
        status_online: 'Online',
        status_offline: 'Offline',
        status_checking: 'Checking...',
        status_keys_issued: 'Keys issued',
        status_worker: 'Worker',
        ticket_title: 'Key Support Ticket',
        ticket_desc: 'A support channel has been created for you.',
        ticket_created: 'Ticket created: {channel}',
        ticket_already: 'You already have an open ticket: {channel}',
        ticket_closed: 'Ticket closed by {user}.',
        ticket_close_button: 'Close Ticket',
        ticket_wait: 'Please wait for a support team member.',
        help_title: 'FeatherHub Bot Commands',
        help_verify: 'Verify yourself to access the server',
        help_status: 'Check key system status',
        help_ticket: 'Open a key support ticket',
        help_help: 'Show this help message',
        no_perms: 'You do not have permission to use this command.',
        error: 'An error occurred. Please try again later.',
    },
    ru: {
        verify_title: 'Верификация',
        verify_desc: 'Нажми кнопку ниже, чтобы получить доступ к серверу.',
        verify_button: 'Верифицироваться',
        verified: 'Ты верифицирован! Добро пожаловать в FeatherHub.',
        already_verified: 'Ты уже верифицирован.',
        ban_warning: 'Этот канал только для чтения. Сообщение здесь = бан.',
        ban_log: 'Пользователь {user} ({id}) забанен за сообщение в #{channel}.',
        ban_reason: 'Сообщение в канале только для чтения',
        status_title: 'Статус системы ключей FeatherHub',
        status_online: 'Онлайн',
        status_offline: 'Оффлайн',
        status_checking: 'Проверка...',
        status_keys_issued: 'Ключей выдано',
        status_worker: 'Воркер',
        ticket_title: 'Тикет поддержки ключей',
        ticket_desc: 'Канал поддержки создан для тебя.',
        ticket_created: 'Тикет создан: {channel}',
        ticket_already: 'У тебя уже есть открытый тикет: {channel}',
        ticket_closed: 'Тикет закрыт пользователем {user}.',
        ticket_close_button: 'Закрыть тикет',
        ticket_wait: 'Подожди, пока кто-то из поддержки ответит.',
        help_title: 'Команды бота FeatherHub',
        help_verify: 'Верифицироваться для доступа к серверу',
        help_status: 'Проверить статус системы ключей',
        help_ticket: 'Открыть тикет поддержки ключей',
        help_help: 'Показать эту справку',
        no_perms: 'Недостаточно прав для этой команды.',
        error: 'Произошла ошибка. Попробуй позже.',
    }
};

function t(lang, key) {
    return T[lang]?.[key] || T.en[key] || key;
}

function getLang(member) {
    // Check if user has a language role, default to EN
    if (!member) return 'en';
    if (member.roles.cache.some(r => r.name.toLowerCase().includes('ru') || r.name.toLowerCase().includes('рус'))) return 'ru';
    return 'en';
}

// ════════════════════════════════════════════════════════════════
// CLIENT
// ════════════════════════════════════════════════════════════════
const client = new Client({
    intents: [
        GatewayIntentBits.Guilds,
        GatewayIntentBits.GuildMembers,
        GatewayIntentBits.GuildMessages,
        GatewayIntentBits.MessageContent,
        GatewayIntentBits.GuildMessageReactions,
    ],
    partials: [Partials.Channel],
});

// ════════════════════════════════════════════════════════════════
// READY
// ════════════════════════════════════════════════════════════════
client.once(Events.ClientReady, async (c) => {
    console.log(`[FeatherHub Bot] Logged in as ${c.user.tag}`);

    // Register slash commands
    const guild = await client.guilds.fetch(CONFIG.guildId);
    await guild.commands.set([
        {
            name: 'verify',
            description: 'Verify yourself to access the server',
            description_localizations: { ru: 'Верифицироваться для доступа к серверу' },
        },
        {
            name: 'status',
            description: 'Check key system status',
            description_localizations: { ru: 'Проверить статус системы ключей' },
        },
        {
            name: 'ticket',
            description: 'Open a key support ticket',
            description_localizations: { ru: 'Открыть тикет поддержки ключей' },
        },
        {
            name: 'help',
            description: 'Show bot commands',
            description_localizations: { ru: 'Показать команды бота' },
        },
        {
            name: 'setup-verify',
            description: 'Post verification message in current channel',
            description_localizations: { ru: 'Отправить сообщение верификации в этот канал' },
            default_member_permissions: PermissionFlagsBits.Administrator.toString(),
        },
    ]);
    console.log('[FeatherHub Bot] Commands registered.');
});

// ════════════════════════════════════════════════════════════════
// BAN CHANNEL — auto-ban on message
// ════════════════════════════════════════════════════════════════
client.on(Events.MessageCreate, async (message) => {
    if (message.author.bot) return;
    if (message.channelId !== CONFIG.channels.ban) return;

    const lang = getLang(message.member);

    try {
        // Delete the message first
        await message.delete().catch(() => {});

        // Ban the user
        await message.member.ban({
            reason: t(lang, 'ban_reason'),
            deleteMessageSeconds: 0,
        });

        // Log
        const logChannel = client.channels.cache.get(CONFIG.channels.log);
        if (logChannel) {
            const embed = new EmbedBuilder()
                .setColor(0xff4444)
                .setTitle('Auto-Ban')
                .setDescription(
                    t(lang, 'ban_log')
                        .replace('{user}', message.author.tag)
                        .replace('{id}', message.author.id)
                        .replace('{channel}', message.channel.name)
                )
                .setTimestamp();
            await logChannel.send({ embeds: [embed] });
        }
    } catch (err) {
        console.error('[Ban Channel Error]', err);
    }
});

// ════════════════════════════════════════════════════════════════
// SLASH COMMANDS
// ════════════════════════════════════════════════════════════════
client.on(Events.InteractionCreate, async (interaction) => {
    if (!interaction.isChatInputCommand() && !interaction.isButton()) return;

    const lang = getLang(interaction.member);

    // ── /verify ──
    if (interaction.isChatInputCommand() && interaction.commandName === 'verify') {
        await interaction.deferReply({ ephemeral: true });

        const member = interaction.member;
        const verifiedRole = interaction.guild.roles.cache.get(CONFIG.roles.verified);

        if (member.roles.cache.has(CONFIG.roles.verified)) {
            return interaction.editReply({ content: t(lang, 'already_verified') });
        }

        if (verifiedRole) {
            await member.roles.add(verifiedRole).catch(() => {});
        }

        const embed = new EmbedBuilder()
            .setColor(0x4ade80)
            .setTitle(t(lang, 'verified'))
            .setFooter({ text: 'FeatherHub' });

        await interaction.editReply({ embeds: [embed] });
    }

    // ── /status ──
    if (interaction.isChatInputCommand() && interaction.commandName === 'status') {
        await interaction.deferReply();

        let statusText = t(lang, 'status_offline');
        let statusColor = 0xff4444;
        let workerHealth = 'N/A';

        try {
            const res = await fetch(CONFIG.keyWorker + '/health', {
                signal: AbortSignal.timeout(10000),
            });
            if (res.ok) {
                const data = await res.json();
                statusText = t(lang, 'status_online');
                statusColor = 0x4ade80;
                workerHealth = data.service || 'featherhub-keys';
            }
        } catch {
            statusText = t(lang, 'status_offline');
        }

        const embed = new EmbedBuilder()
            .setColor(statusColor)
            .setTitle(t(lang, 'status_title'))
            .addFields(
                { name: t(lang, 'status_worker'), value: workerHealth, inline: true },
                { name: 'Status', value: statusText, inline: true },
                { name: 'URL', value: CONFIG.keyWorker, inline: false },
            )
            .setTimestamp()
            .setFooter({ text: 'FeatherHub' });

        await interaction.editReply({ embeds: [embed] });
    }

    // ── /ticket ──
    if (interaction.isChatInputCommand() && interaction.commandName === 'ticket') {
        await interaction.deferReply({ ephemeral: true });

        const member = interaction.member;
        const guild = interaction.guild;

        // Check if user already has a ticket
        const existingChannel = guild.channels.cache.find(
            ch => ch.type === ChannelType.GuildText && ch.name === `ticket-${member.user.id}`
        );

        if (existingChannel) {
            return interaction.editReply({
                content: t(lang, 'ticket_already').replace('{channel}', existingChannel.toString()),
            });
        }

        // Create ticket channel
        const category = CONFIG.channels.ticketCategory
            ? guild.channels.cache.get(CONFIG.channels.ticketCategory)
            : null;

        const ticketChannel = await guild.channels.create({
            name: `ticket-${member.user.id}`,
            type: ChannelType.GuildText,
            parent: category || null,
            permissionOverwrites: [
                {
                    id: guild.id,
                    deny: [PermissionFlagsBits.ViewChannel],
                },
                {
                    id: member.id,
                    allow: [
                        PermissionFlagsBits.ViewChannel,
                        PermissionFlagsBits.SendMessages,
                        PermissionFlagsBits.ReadMessageHistory,
                    ],
                },
                {
                    id: client.user.id,
                    allow: [
                        PermissionFlagsBits.ViewChannel,
                        PermissionFlagsBits.SendMessages,
                        PermissionFlagsBits.ReadMessageHistory,
                    ],
                },
            ],
        });

        const closeBtn = new ButtonBuilder()
            .setCustomId('close_ticket')
            .setLabel(t(lang, 'ticket_close_button'))
            .setStyle(ButtonStyle.Danger);

        const embed = new EmbedBuilder()
            .setColor(0x7dd3fc)
            .setTitle(t(lang, 'ticket_title'))
            .setDescription(
                `${member.toString()}, ${t(lang, 'ticket_wait')}\n\n${t(lang, 'ticket_desc')}`
            )
            .setFooter({ text: 'FeatherHub Support' })
            .setTimestamp();

        await ticketChannel.send({
            embeds: [embed],
            components: [new ActionRowBuilder().addComponents(closeBtn)],
        });

        // Log
        const logChannel = client.channels.cache.get(CONFIG.channels.log);
        if (logChannel) {
            const logEmbed = new EmbedBuilder()
                .setColor(0x7dd3fc)
                .setTitle('Ticket Created')
                .setDescription(`${member.toString()} created ticket ${ticketChannel.toString()}`)
                .setTimestamp();
            await logChannel.send({ embeds: [logEmbed] });
        }

        await interaction.editReply({
            content: t(lang, 'ticket_created').replace('{channel}', ticketChannel.toString()),
        });
    }

    // ── /help ──
    if (interaction.isChatInputCommand() && interaction.commandName === 'help') {
        const embed = new EmbedBuilder()
            .setColor(0x7dd3fc)
            .setTitle(t(lang, 'help_title'))
            .addFields(
                { name: '/verify', value: t(lang, 'help_verify'), inline: false },
                { name: '/status', value: t(lang, 'help_status'), inline: false },
                { name: '/ticket', value: t(lang, 'help_ticket'), inline: false },
                { name: '/help', value: t(lang, 'help_help'), inline: false },
            )
            .setFooter({ text: 'FeatherHub' });

        await interaction.reply({ embeds: [embed], ephemeral: true });
    }

    // ── /setup-verify (admin only) ──
    if (interaction.isChatInputCommand() && interaction.commandName === 'setup-verify') {
        if (!interaction.member.permissions.has(PermissionFlagsBits.Administrator)) {
            return interaction.reply({ content: t(lang, 'no_perms'), ephemeral: true });
        }

        const btn = new ButtonBuilder()
            .setCustomId('verify_btn')
            .setLabel(t(lang, 'verify_button'))
            .setStyle(ButtonStyle.Success);

        const embed = new EmbedBuilder()
            .setColor(0x7dd3fc)
            .setTitle(t(lang, 'verify_title'))
            .setDescription(t(lang, 'verify_desc'))
            .setFooter({ text: 'FeatherHub' });

        await interaction.channel.send({
            embeds: [embed],
            components: [new ActionRowBuilder().addComponents(btn)],
        });

        await interaction.reply({ content: 'Verification message posted.', ephemeral: true });
    }

    // ── Verify button ──
    if (interaction.isButton() && interaction.customId === 'verify_btn') {
        await interaction.deferReply({ ephemeral: true });

        const member = interaction.member;
        const verifiedRole = interaction.guild.roles.cache.get(CONFIG.roles.verified);

        if (member.roles.cache.has(CONFIG.roles.verified)) {
            return interaction.editReply({ content: t(lang, 'already_verified') });
        }

        if (verifiedRole) {
            await member.roles.add(verifiedRole).catch(() => {});
        }

        const embed = new EmbedBuilder()
            .setColor(0x4ade80)
            .setTitle(t(lang, 'verified'))
            .setFooter({ text: 'FeatherHub' });

        await interaction.editReply({ embeds: [embed] });
    }

    // ── Close ticket button ──
    if (interaction.isButton() && interaction.customId === 'close_ticket') {
        const channel = interaction.channel;
        if (!channel.name.startsWith('ticket-')) return;

        await interaction.deferReply();

        const embed = new EmbedBuilder()
            .setColor(0xff4444)
            .setTitle(t(lang, 'ticket_closed').replace('{user}', interaction.user.tag))
            .setTimestamp();

        await channel.send({ embeds: [embed] });

        // Log
        const logChannel = client.channels.cache.get(CONFIG.channels.log);
        if (logChannel) {
            const logEmbed = new EmbedBuilder()
                .setColor(0xff4444)
                .setTitle('Ticket Closed')
                .setDescription(`${interaction.user.tag} closed ${channel.toString()}`)
                .setTimestamp();
            await logChannel.send({ embeds: [logEmbed] });
        }

        // Delete after 5 seconds
        setTimeout(() => channel.delete().catch(() => {}), 5000);
    }
});

// ════════════════════════════════════════════════════════════════
// LOGIN
// ════════════════════════════════════════════════════════════════
client.login(CONFIG.token).catch(err => {
    console.error('[FeatherHub Bot] Login failed:', err.message);
    process.exit(1);
});
