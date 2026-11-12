/**
 * Mirror of the API's deny-list (backend/internal/auth/policy.go) so the
 * sign-up hints match what the server will accept. The server remains the
 * authority; keep this list in sync when the backend list changes.
 */
export const COMMON_PASSWORDS: ReadonlySet<string> = new Set(
  `password password1 password123 passw0rd 1234567890 12345678910 qwertyuiop
  qwerty123 qwerty1234 iloveyou123 welcome123 letmein123 admin12345 administrator abc1234567 1q2w3e4r5t
  1qaz2wsx3edc zaq12wsxcde football123 baseball123 sunshine123 princess123 monkey12345 dragon12345
  trustno1234 superman123 starwars123 whatever123 freedom123 changeme123 montra1234 montra12345 india12345
  password@123 Password@123 pass@12345 asdfghjkl1 zxcvbnm123 qazwsxedc1 11111111111 00000000000 9876543210
  welcome@123 test123456 testtest12 secret12345 mypassword1 summer2024 winter2024 spring2025 autumn2025`
    .split(/\s+/)
    .filter(Boolean)
    .map((password) => password.toLowerCase()),
);
