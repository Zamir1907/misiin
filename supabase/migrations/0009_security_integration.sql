-- Misiin Stage 11: additive security hardening after 0008_settings.sql.
-- Review in staging before production. Does not delete existing data.
BEGIN;
-- Disallow clients from invoking privileged helpers directly.
REVOKE ALL ON FUNCTION public.grant_wallet_bonus(uuid,text,text,text) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.wallet_setting(text) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.admin_assert() FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.admin_log(text,uuid,jsonb) FROM PUBLIC,anon,authenticated;
-- A member should not query another user's paid entitlement.
CREATE OR REPLACE FUNCTION public.misiin_has_plus(p_user uuid)
RETURNS boolean LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF auth.role() NOT IN ('service_role') AND (auth.uid() IS NULL OR auth.uid()<>p_user) AND NOT public.misiin_is_admin() THEN
  RAISE EXCEPTION 'Akses ditolak' USING ERRCODE='42501';
 END IF;
 RETURN EXISTS(SELECT 1 FROM public.memberships WHERE user_id=p_user AND tier='plus_lifetime' AND status='active');
END $$;
REVOKE ALL ON FUNCTION public.misiin_has_plus(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.misiin_has_plus(uuid) TO authenticated,service_role;
-- Enforce suspended account status at the RPC boundary, not only in UI.
CREATE OR REPLACE FUNCTION public.misiin_assert_active(p_user uuid)
RETURNS void LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF p_user IS NULL OR (auth.role()<>'service_role' AND auth.uid() IS DISTINCT FROM p_user) THEN
  RAISE EXCEPTION 'Akses ditolak' USING ERRCODE='42501';
 END IF;
 IF EXISTS(SELECT 1 FROM public.user_restrictions WHERE user_id=p_user AND suspended) THEN
  RAISE EXCEPTION 'Akun sedang dibatasi' USING ERRCODE='42501';
 END IF;
END $$;
REVOKE ALL ON FUNCTION public.misiin_assert_active(uuid) FROM PUBLIC,anon,authenticated;
-- Prevent a withdrawal from pointing to an account belonging to another user.
CREATE OR REPLACE FUNCTION public.misiin_check_withdrawal_account()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF NOT EXISTS (SELECT 1 FROM public.withdrawal_accounts WHERE id=NEW.account_id AND user_id=NEW.user_id) THEN
  RAISE EXCEPTION 'Rekening tidak sesuai dengan pemilik withdraw' USING ERRCODE='23514';
 END IF;
 RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS misiin_withdrawal_account_owner ON public.withdrawal_requests;
CREATE TRIGGER misiin_withdrawal_account_owner BEFORE INSERT OR UPDATE OF account_id,user_id
ON public.withdrawal_requests FOR EACH ROW EXECUTE FUNCTION public.misiin_check_withdrawal_account();
-- A suspended user cannot create a new withdrawal; preserve existing RPC logic.
-- Existing RPCs must be amended individually to call misiin_assert_active; audit flags this as follow-up.
-- Ensure paid transaction identifiers are unique across gateway event IDs.
CREATE UNIQUE INDEX IF NOT EXISTS payment_provider_reference_unique
ON public.payment_orders(gateway_provider,gateway_reference)
WHERE gateway_provider IS NOT NULL AND gateway_reference IS NOT NULL;
-- Read-only auditing metadata.
CREATE TABLE IF NOT EXISTS public.integration_audit_versions (
 version text PRIMARY KEY, applied_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.integration_audit_versions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.integration_audit_versions FROM anon,authenticated;
INSERT INTO public.integration_audit_versions(version) VALUES('0009_security_integration') ON CONFLICT DO NOTHING;
COMMIT;
