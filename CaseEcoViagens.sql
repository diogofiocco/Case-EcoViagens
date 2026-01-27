
--- Acompanhar o desempenho financeiro geral da plataforma através de métrica de receita total por período para monitorar o crescimento do negócio e identificar sazonalidades.

-- 1: receita total por mês

-- total da receita: preço da reserva * qtd_pessoas
SELECT
extract(year from r.data_reserva) as ano, -- extração do ano
format_date('%B', date(r.data_reserva)) as nome_mes, -- extração do mês como nome (string)
round(sum(o.preco * r.qtd_pessoas), 2) as receita_total -- extração da receita
from `ecoviagens-477223.plataforma.reservas` r
inner join `ecoviagens-477223.plataforma.ofertas` o 
on r.id_oferta = o.id_oferta
where upper(r.status) = 'CONCLUÍDA' -- receita calculada para reservas concluidas
group by ano, nome_mes, extract(month from r.data_reserva) -- extract como coluna auxiliar para ordenar os meses
order by ano desc, extract(month from r.data_reserva) desc;

-- Análise: Estratégias usadas no início do ano, como companhas promocionais, podem ter resultado na maior receita no mês de março, ou esse aumento é decorrente da sazonalidade? A integração com variáveis de marketing aprofundariam o diagnóstico para tomada de decisões

-- Taxa de variação percentual da receita em relação ao mês anterior
with receita_mensal as (
  select
  date_trunc(data_reserva, MONTH) AS mes,
  round(sum (o.preco * r.qtd_pessoas), 2) as receita_total
  from `ecoviagens-477223.plataforma.reservas` r
  inner join `ecoviagens-477223.plataforma.ofertas` o on r.id_oferta = o.id_oferta
  where upper (r.status) = 'CONCLUÍDA'
  group by mes
)

select
  mes,
  receita_total,
  round(lag (receita_total) over (order by mes), 2) as receita_anterior,
  round(
    safe_divide(receita_total - lag(receita_total) over (order by mes),
    lag(receita_total) over (order by mes)) * 100, 2
  ) as variacao_percentual
  from receita_mensal
  order by mes;
  -- A variação mais expressiva foi no mes de out/24,registrando um aumento de 43,68% em relação ao mês anterior. Tal variação infica um período de alta demanda devido a possiveis eventos de sazonalidade, feriados ou campanhas promocionais. O mês de jun/25 pode ser desconsiderado na análise pois os dados não são referentes ao mês todo. Os mês com maior variação negativa foram jul/24 e abr/25, o que comprovam a necessidade de implementar estratégias de marketing e oferta para minimizar a queda de performance.


---2: Entender se os clientes estão investindo mais em experiências premium ou optando por opções econômicas.
-- ticket médio por pessoa.
-- preco * qtd_pessoas -> valor total pago por reserva
-- soma de todo valor por reserva
-- dividir pelo total de pessoas em todas as reservas
select
round(sum(o.preco * r.qtd_pessoas)/sum(r.qtd_pessoas), 2) as media_gastos
from `ecoviagens-477223.plataforma.reservas` r
inner join `ecoviagens-477223.plataforma.ofertas` o 
on r.id_oferta = o.id_oferta
where upper(r.status) = 'CONCLUÍDA'
-- Com esse cálculo de media dos gastos, não é possível identificar se os clientes estão gastando em reservas mais caras ou mais baratas (media = 276,88 reais)
-- Cáluclo de mediana, métrica para não ser influenciada por outliers (mediana = 275,89 reais)
select
percentile_cont(preco, 0.5) over() as mediana_preco -- percentil de 50%
from `ecoviagens-477223.plataforma.ofertas` limit 1
-- Como média e mediana não tiveram variação alta, pode-se dizer que os clientes estão optando por ofertas com preço mais acessível. 


---3: Identificar quais tipos de ofertas são mais populares considerando a quantidade de ofertas
-- Considerando a popularidade por distribuição das reservas e por tipo de oferta com mais viajantes
select
o.tipo_oferta as tipo_oferta,
count(r.id_reserva) as total_reserva,-- contagem da quantidade de reservas
sum(r.qtd_pessoas) as total_viajantes -- soma da quantidade de pessoas por tipo de oferta
from `ecoviagens-477223.plataforma.reservas` r
inner join `ecoviagens-477223.plataforma.ofertas` o 
on r.id_oferta = o.id_oferta
group by 1;
-- Houve um total de 1053 reservas de hospedagem e 947 reservas de atividade. Já na quantidade de viajantes foram 3043 para hospedagem contra 2801 para atividade. Em ambos os casos a hospedagem foi superior.

---4: Taxa de fidelização dos clientes: quantidade de clientes fieis / quantidade de clientes que já reservaram
-- lista de clientes que fizeram mais do que uma reserva com status concluída
-- contar quantos clientes são fieis
-- Dividir a quantidade de clientes fieis (valor anterior) pelo total de clientes que fizeram pelo menos uma reserva concluida
select
  ROUND(count(*) / (
    select
      count(distinct id_cliente)
    from `ecoviagens-477223.plataforma.reservas`
    where upper(status) = 'CONCLUÍDA'-- contagem de clientes com reserva concluída = 614
  ), 2)*100 as porcentagem_fidelizacao    

from(
  select
  id_cliente
  from `ecoviagens-477223.plataforma.reservas`
  where upper(status) = 'CONCLUÍDA'
  group by id_cliente
  having count(id_reserva) > 1 -- clientes com mais de uma reserva
) clientes_fieis;
-- A taxa de fidelização de clientes que fizeram mais de uma reserva com status concluído foi de 23%. Essa taxa de fidelização pode ser aumentada com descontos progressivos nas reservas.

---5: Avaliação média das ofertas
select
  o.id_oferta,
  o.titulo,
  round(avg(a.nota), 2) as media_nota,
  case
    when count(distinct r.id_reserva) = 0 then 'Sem Reserva Concluída'
    when count(distinct r.id_reserva) > 0 and count(distinct a.id_avaliacao) = 0 then 'Reserva concluída mas sem avaliação'
    else 'Reserva e avaliação presentes' -- query usada devido ao uso do left join entre ofertas e reservas
  end as status_oferta  
from `ecoviagens-477223.plataforma.ofertas` o
left join `ecoviagens-477223.plataforma.reservas` r on o.id_oferta = r.id_oferta and upper(r.status) = 'CONCLUÍDA'
left join `ecoviagens-477223.plataforma.avaliacoes` a on a.id_oferta = r.id_oferta
group by 1, 2
order by media_nota desc;

---6: Indice de adoção de práticas sustentáveis (quantidade de ofertas com pratica sustentaveis / total de ofertas da plataforma)

select 
  count (distinct id_oferta)
  from `ecoviagens-477223.plataforma.oferta_pratica`; -- 802 ofertas com práticas sustentáveis

select
  round(count(distinct op.id_oferta) / ( -- contagem de ofertas com pratica sustentavel da tabela de oferta pratica (tabela de id_oferta com id_pratica)
    select
      count(distinct id_oferta) -- contagem total de ofertas da tabela de ofertas
  from `ecoviagens-477223.plataforma.ofertas`), 2)*100 as indice_sustentavel_pct
from `ecoviagens-477223.plataforma.oferta_pratica` op
-- 67% das ofertas possuem práticas sustentáveis. Quanto maior esse índice, mais estará alinhado com o propósito de sustentabilidade da empresa.

---7: Práticas sustentáveis mais procuradas

select
  ps.nome,
  count(r.id_reserva) as total_reservas
from `ecoviagens-477223.plataforma.praticas_sustentaveis` ps
inner join `ecoviagens-477223.plataforma.oferta_pratica` op on ps.id_pratica = op.id_pratica -- base de dados que interliga as tabelas
inner join `ecoviagens-477223.plataforma.reservas` r on op.id_oferta = r.id_oferta and upper(r.status) = 'CONCLUÍDA'
group by ps.nome
order by total_reservas desc;

---8: Identificar com que frequência os clientes fieis fazem novas reservas
-- filtrar clientes fieis (clientes que fizeram mais de uma reserva concluída)
-- calcular a diferença de tempo entre as reservas
-- média dos intervalos encontrados

with reservas_filtradas as( -- CTE para filtrar reservas concluídas e clientes com mais de uma reserva 
  select
  id_cliente,
  data_reserva
  from `ecoviagens-477223.plataforma.reservas`
  where upper(status) = 'CONCLUÍDA'
    AND id_cliente in (
      select -- subquery para filtrar contar os clientes com mais de uma reserva concluída
        id_cliente
      from `ecoviagens-477223.plataforma.reservas`
      where upper(status) = 'CONCLUÍDA'
      group by id_cliente
      having count(id_reserva) > 1  
    )
),

diferenca as ( -- diferença dos tempos de reserva
  select
    id_cliente,
    date_diff(
      data_reserva,
      lag(data_reserva) over (partition by id_cliente order by data_reserva), -- lag usado para comparar dados da linha anterior (data)
      DAY
    ) as diff_dias,
    data_reserva
  from reservas_filtradas
)

select
  id_cliente,
  avg(diff_dias) as tempo_medio_reservas, -- media de dias entre reservas
from diferenca
where diff_dias is not null
group by id_cliente
order by tempo_medio_reservas desc;
-- A análise permite planejar campanhas de engajamento em momentos mais assertivos

--- 9: Desempenho médio dos operadores por categoria de oferta
-- tabelas de avaliacoes, ofertas, reservas e operadores

with reservas_concluidas as(
  select
    distinct (id_oferta) AS id_oferta
  from `ecoviagens-477223.plataforma.reservas`
  where upper(status) = 'CONCLUÍDA' -- CTE para selecionar apenas reservas concluidas
)

select
  op.nome_fantasia,
  o.tipo_oferta,
  round(AVG(a.nota), 2) as media_avaliacao
from `ecoviagens-477223.plataforma.avaliacoes` a 
inner join `ecoviagens-477223.plataforma.ofertas` o on a.id_oferta = o.id_oferta
inner join reservas_concluidas rs on rs.id_oferta = o.id_oferta
inner join `ecoviagens-477223.plataforma.operadores` op on op.id_operador = o.id_operador
group by 1, 2
order by 2, 3 desc;