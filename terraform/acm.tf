resource "aws_acm_certificate" "wildcard" {
  domain_name               = var.acm_domain_name
  subject_alternative_names = [trimprefix(var.acm_domain_name, "*.")]
  validation_method         = "DNS"
}

resource "cloudflare_dns_record" "acm" {
  zone_id = "e7a92c9cefa2fec6d0bbd02610d1de15"
  name = trimsuffix(
    tolist(aws_acm_certificate.wildcard.domain_validation_options)[0].resource_record_name,
    ".${var.cloudflare_zone_name}.",
  )
  type = tolist(aws_acm_certificate.wildcard.domain_validation_options)[0].resource_record_type
  content = trimsuffix(
    tolist(aws_acm_certificate.wildcard.domain_validation_options)[0].resource_record_value,
    ".",
  )
  ttl     = 60
  proxied = false
  comment = "ACM DNS validation"
}

resource "aws_acm_certificate_validation" "wildcard" {
  certificate_arn = aws_acm_certificate.wildcard.arn
  validation_record_fqdns = [
    for dvo in aws_acm_certificate.wildcard.domain_validation_options :
    dvo.resource_record_name
  ]

  depends_on = [cloudflare_dns_record.acm]
}
