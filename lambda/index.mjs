import mysql from 'mysql2/promise';
import { CognitoIdentityClient, GetIdCommand, GetCredentialsForIdentityCommand } from "@aws-sdk/client-cognito-identity";
import jwt from 'jsonwebtoken';

const env  = {
    ProxyHostName: "my-mysql-db.cj6euai841aq.us-east-2.rds.amazonaws.com",
    Port: 3306,
    DBUserName: "admin",
    AWS_REGION: "us-east-2",
    DBName: "pedido_db",
    DBPassword: "582adfEt",
    IdentityPoolId: "us-east-2:820975dc-bc52-4798-888e-60a000be077b"
}

const JWT_SECRET = "e8f3b2c7d9a1f4g5h6j7k8l9m0n1p2q3r4s5t6u7v8w9x0y1z2a3b4c5d6e7"; // Substitua por uma chave secreta segura
const JWT_EXPIRATION = "1h"; // Tempo de expiração do token (1 hora)

async function dbConection() {
  const connectionConfig = {
    host: env.ProxyHostName,
    user: env.DBUserName,
    database: env.DBName,
    password: env.DBPassword,
  };
  return await mysql.createConnection(connectionConfig);
}

async function dbQuery(sql, params) {
    const conection = await dbConection();
    const [res,] = await conection.execute(sql, params);
    return res;
}

async function getTemporaryCredentials() {

    const cognitoClient = new CognitoIdentityClient({ region: env.AWS_REGION }); 

    try {
      // Obter uma identidade para o usuário não autenticado
      const identityIdResponse = await cognitoClient.send(
        new GetIdCommand({
          IdentityPoolId: env.IdentityPoolId,
        })
      );
  
      // Obter credenciais temporárias para a identidade
      const credentialsResponse = await cognitoClient.send(
        new GetCredentialsForIdentityCommand({
          IdentityId: identityIdResponse.IdentityId,
        })
      );
  
      return credentialsResponse.Credentials;
    } catch (error) {
      console.error("Error getting temporary credentials:", error);
      throw new Error("Failed to get temporary credentials");
    }
  }

  async function generateJWT(user, credentials) {
    const payload = {
      userId: user.id, // ID do usuário do banco de dados
      nome: user.nome, // Nome do usuário
      cpf: user.cpf, // CPF do usuário
      awsCredentials: {
        accessKeyId: credentials.AccessKeyId,
        secretAccessKey: credentials.SecretKey,
        sessionToken: credentials.SessionToken,
      },
    };
  
    // Gera o token JWT
    const token = jwt.sign(payload, JWT_SECRET, { expiresIn: JWT_EXPIRATION });
    return token;
  }
  

export const handler = async (event) => {

  const result = await dbQuery('SELECT * FROM `usuario` AS `u` WHERE `u`.`cpf` = ?', [event.cpf]);

  if(result && result.length > 0){
      
    const credentials = await getTemporaryCredentials();
      
    const jwtToken = await generateJWT(result[0], credentials);

    return {
      statusCode: 200,
      body: JSON.stringify("The selected sum is: " + result[0].nome),
      token: jwtToken
    }
  } else {
    return {
      statusCode: 404,
      body: JSON.stringify("User not found")
    }
  }
};