/**
 * Database Sanitization & Pruning Script
 * 
 * Retains strictly:
 * - Active User: chandra77807@gmail.com
 * - Active Home: a76e6dc6-e662-43a4-9a08-de52ce218ef1 (My Home)
 * - Single Living Room in My Home (deduplicated)
 * - Active Connected Device: bcae1ecc-ddf3-4509-8317-f16298267bd2 (EH Smart Switch 4X)
 * 
 * Wipes all legacy, test, and dummy data.
 */

const { Client } = require('pg');

const DATABASE_URL = process.env.DATABASE_URL || 'postgresql://eh_admin:eh_development_password_only@localhost:5432/eh_home_dev';

async function main() {
  const client = new Client({ connectionString: DATABASE_URL });

  try {
    await client.connect();
    console.log('Connected to PostgreSQL database for pruning.');

    // 1. Identify User
    const userRes = await client.query("SELECT id, email FROM users WHERE email = 'chandra77807@gmail.com'");
    if (userRes.rows.length === 0) {
      throw new Error("Target user 'chandra77807@gmail.com' not found in database!");
    }
    const targetUserId = userRes.rows[0].id;
    console.log(`Preserving User: ${userRes.rows[0].email} (${targetUserId})`);

    // 2. Identify Device
    const devRes = await client.query("SELECT id, serial_number FROM devices WHERE id LIKE '%bcae1ecc%'");
    if (devRes.rows.length === 0) {
      throw new Error("Target device 'bcae1ecc' not found in database!");
    }
    const targetDeviceId = devRes.rows[0].id;
    console.log(`Preserving Device: ${targetDeviceId}`);

    // Update target device to 4X variant if needed
    await client.query(`
      UPDATE devices 
      SET product_variant_id = 'eh-smart-switch-4x',
          firmware_family = 'eh-smart-switch',
          updated_at = NOW()
      WHERE id = $1
    `, [targetDeviceId]);
    console.log(`Updated device ${targetDeviceId} to eh-smart-switch-4x.`);

    // 3. Identify Home
    const homeRes = await client.query("SELECT id, name FROM homes WHERE owner_id = $1 ORDER BY created_at ASC LIMIT 1", [targetUserId]);
    let targetHomeId = homeRes.rows[0]?.id;
    if (!targetHomeId) {
      const fallbackHome = await client.query("SELECT id, name FROM homes WHERE id = 'a76e6dc6-e662-43a4-9a08-de52ce218ef1'");
      targetHomeId = fallbackHome.rows[0]?.id;
    }
    console.log(`Preserving Home: ${targetHomeId}`);

    // 4. Deduplicate Rooms for this Home: Keep exactly 1 Living Room
    const roomsRes = await client.query("SELECT id, name FROM rooms WHERE home_id = $1 ORDER BY created_at ASC", [targetHomeId]);
    let targetRoomId = null;
    const roomsToDelete = [];
    for (const r of roomsRes.rows) {
      if (!targetRoomId && r.name.toLowerCase() === 'living room') {
        targetRoomId = r.id;
      } else {
        roomsToDelete.push(r.id);
      }
    }
    if (roomsToDelete.length > 0) {
      await client.query("DELETE FROM rooms WHERE id = ANY($1)", [roomsToDelete]);
      console.log(`Deleted ${roomsToDelete.length} redundant/duplicate room entries.`);
    }

    // 5. Ensure Device Authorization is Clean and Linked to Living Room
    await client.query(`
      DELETE FROM device_authorizations WHERE device_id != $1
    `, [targetDeviceId]);

    await client.query(`
      INSERT INTO device_authorizations (device_id, home_id, room_id, custom_name, channel_labels, channel_configs, claimed_at, claimed_by_user_id)
      VALUES ($1, $2, $3, 'EH Smart Switch 4X', '{}'::jsonb, '{}'::jsonb, NOW(), $4)
      ON CONFLICT (device_id) DO UPDATE SET
        home_id = $2,
        room_id = $3,
        custom_name = 'EH Smart Switch 4X',
        claimed_by_user_id = $4
    `, [targetDeviceId, targetHomeId, targetRoomId, targetUserId]);
    console.log(`Device authorization verified for ${targetDeviceId} in room ${targetRoomId}.`);

    // Ensure 4 channels exist in channel_state for target device
    for (let ch = 1; ch <= 4; ch++) {
      await client.query(`
        INSERT INTO channel_state (id, device_id, channel_index, desired_state, reported_state, confidence, updated_at)
        VALUES ($1, $2, $3, '{"power":false}'::jsonb, '{"power":false}'::jsonb, 'CONFIRMED', NOW())
        ON CONFLICT (id) DO NOTHING
      `, [`${targetDeviceId}_ch_${ch}`, targetDeviceId, ch]);
    }

    // 6. Delete all OTHER devices and their states
    await client.query("DELETE FROM channel_state WHERE device_id != $1", [targetDeviceId]);
    await client.query("DELETE FROM device_state WHERE device_id != $1", [targetDeviceId]);
    await client.query("DELETE FROM device_events WHERE device_id != $1", [targetDeviceId]);
    await client.query("DELETE FROM device_credentials WHERE device_id != $1", [targetDeviceId]);
    await client.query("DELETE FROM device_connection_states WHERE device_id != $1", [targetDeviceId]);
    await client.query("DELETE FROM devices WHERE id != $1", [targetDeviceId]);
    console.log(`Cleaned up all dummy/unclaimed devices.`);

    // 7. Delete all OTHER homes and memberships
    await client.query("DELETE FROM home_memberships WHERE home_id != $1", [targetHomeId]);
    await client.query("DELETE FROM rooms WHERE home_id != $1", [targetHomeId]);
    await client.query("DELETE FROM automations WHERE home_id != $1", [targetHomeId]);
    await client.query("DELETE FROM homes WHERE id != $1", [targetHomeId]);
    console.log(`Cleaned up all dummy/legacy homes.`);

    // 8. Delete all OTHER users
    await client.query("DELETE FROM user_profiles WHERE id != $1", [targetUserId]);
    await client.query("DELETE FROM refresh_tokens WHERE user_id != $1", [targetUserId]);
    await client.query("DELETE FROM push_device_tokens WHERE user_id != $1", [targetUserId]);
    await client.query("DELETE FROM users WHERE id != $1", [targetUserId]);
    console.log(`Cleaned up all dummy users. Retained: ${userRes.rows[0].email}`);

    // 9. Clean up audit logs for deleted devices
    await client.query("DELETE FROM audit_logs WHERE device_id IS NOT NULL AND device_id != $1", [targetDeviceId]);
    console.log(`Pruned audit logs.`);

    console.log('\n============================================================');
    console.log(' DATABASE PRUNING & REORGANIZATION COMPLETED SUCCESSFULLY!  ');
    console.log('============================================================');

  } catch (err) {
    console.error('Error pruning database:', err);
  } finally {
    await client.end();
  }
}

if (require.main === module) {
  main();
}

module.exports = { main };
