# Ele especifica que o tipo de backend é "s3", o que significa que o Terraform armazenará seus arquivos de estado em um bucket do S3.
# Quando o Guhub Actions executar o terraform, os arquivos State File (.tfstate) serão criados no bucket S3.

# Sem especificar onde os arquivos serão salvos o GitHub Actions irá utilizar o runner do GitHub Actions
# Mas esse ambiente é destruído ao final do job, então o terraform.tfstate é perdido após cada execução.
# Isso quebra a persistência do estado e pode causar problemas como duplicação de recursos.

terraform {
    backend "s3" {}
}